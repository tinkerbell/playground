package e2e

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"gopkg.in/yaml.v3"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// CAPI and CAPT API groups. Kinds are resolved to a served version through the
// RESTMapper, so a storage version bump needs no change here.
const (
	clusterAPIGroup      = "cluster.x-k8s.io"
	controlPlaneAPIGroup = "controlplane.cluster.x-k8s.io"
	infraAPIGroup        = "infrastructure.cluster.x-k8s.io"
)

// requiredWorkloadComponents are matched as pod name prefixes; each must have at
// least one ready pod somewhere on the workload cluster.
var requiredWorkloadComponents = []string{
	"etcd",
	"kube-apiserver",
	"kube-controller-manager",
	"kube-scheduler",
	"kube-proxy",
	"coredns",
	"kube-router",
}

// Container waiting reasons that never clear without intervention.
var terminalWaitReasons = []string{
	"CreateContainerConfigError",
	"CreateContainerError",
	"InvalidImageName",
}

// Container waiting reasons that may recover on their own, but not indefinitely.
var stuckWaitReasons = []string{
	"CrashLoopBackOff",
	"ImagePullBackOff",
	"ErrImagePull",
}

// How long a stuck reason is tolerated before the wait is abandoned.
const stuckWaitGrace = 2 * time.Minute

// WaitForCAPIReady waits for the CAPI and CAPT objects backing the workload
// cluster to report ready. A terminal failure (failureReason/failureMessage or a
// Failed phase) abandons the wait rather than burning the whole timeout.
func WaitForCAPIReady(ctx context.Context, c client.Client, ns string, controlPlanes, workers int, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for CAPI/CAPT objects in %s to report ready (timeout %s)", ns, timeout))

	machines := int64(controlPlanes + workers)

	Eventually(func(g Gomega) {
		clusters := listKind(ctx, g, c, clusterAPIGroup, "Cluster", ns)
		g.Expect(clusters).To(HaveLen(1), "expected exactly one Cluster in %s, got %d", ns, len(clusters))
		for _, obj := range clusters {
			expectNoTerminalFailure(obj)
			g.Expect(nestedString(obj, "status", "phase")).To(Equal("Provisioned"),
				"cluster/%s phase", obj.GetName())
			expectConditionTrue(g, obj, "Available", "Ready")
			expectConditionTrue(g, obj, "InfrastructureReady")
			expectConditionTrue(g, obj, "ControlPlaneAvailable", "ControlPlaneReady")
		}

		tinkClusters := listKind(ctx, g, c, infraAPIGroup, "TinkerbellCluster", ns)
		g.Expect(tinkClusters).ToNot(BeEmpty(), "no TinkerbellCluster in %s", ns)
		for _, obj := range tinkClusters {
			expectNoTerminalFailure(obj)
			g.Expect(nestedBool(obj, "status", "ready")).To(BeTrue(),
				"tinkerbellcluster/%s is not ready", obj.GetName())
		}

		kcps := listKind(ctx, g, c, controlPlaneAPIGroup, "KubeadmControlPlane", ns)
		g.Expect(kcps).ToNot(BeEmpty(), "no KubeadmControlPlane in %s", ns)
		for _, obj := range kcps {
			expectNoTerminalFailure(obj)
			expectConditionTrue(g, obj, "Available", "Ready")
			g.Expect(nestedInt(obj, "status", "replicas")).To(Equal(int64(controlPlanes)),
				"kubeadmcontrolplane/%s replicas", obj.GetName())
			g.Expect(nestedInt(obj, "status", "readyReplicas")).To(Equal(int64(controlPlanes)),
				"kubeadmcontrolplane/%s readyReplicas", obj.GetName())
		}

		mds := listKind(ctx, g, c, clusterAPIGroup, "MachineDeployment", ns)
		g.Expect(mds).ToNot(BeEmpty(), "no MachineDeployment in %s", ns)
		for _, obj := range mds {
			expectNoTerminalFailure(obj)
			g.Expect(nestedString(obj, "status", "phase")).To(Equal("Running"),
				"machinedeployment/%s phase", obj.GetName())
			g.Expect(nestedInt(obj, "status", "replicas")).To(Equal(int64(workers)),
				"machinedeployment/%s replicas", obj.GetName())
			g.Expect(nestedInt(obj, "status", "readyReplicas")).To(Equal(int64(workers)),
				"machinedeployment/%s readyReplicas", obj.GetName())
			g.Expect(nestedInt(obj, "status", "availableReplicas")).To(Equal(int64(workers)),
				"machinedeployment/%s availableReplicas", obj.GetName())
		}

		capiMachines := listKind(ctx, g, c, clusterAPIGroup, "Machine", ns)
		g.Expect(int64(len(capiMachines))).To(Equal(machines), "expected %d Machines, got %d", machines, len(capiMachines))
		for _, obj := range capiMachines {
			expectNoTerminalFailure(obj)
			g.Expect(nestedString(obj, "status", "phase")).To(Equal("Running"),
				"machine/%s phase", obj.GetName())
			g.Expect(nestedString(obj, "status", "nodeRef", "name")).ToNot(BeEmpty(),
				"machine/%s has no nodeRef", obj.GetName())
			expectConditionTrue(g, obj, "Ready")
		}

		tinkMachines := listKind(ctx, g, c, infraAPIGroup, "TinkerbellMachine", ns)
		g.Expect(int64(len(tinkMachines))).To(Equal(machines),
			"expected %d TinkerbellMachines, got %d", machines, len(tinkMachines))
		for _, obj := range tinkMachines {
			expectNoTerminalFailure(obj)
			g.Expect(nestedBool(obj, "status", "ready")).To(BeTrue(),
				"tinkerbellmachine/%s is not ready", obj.GetName())
		}
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// WaitForAllPodsHealthy waits until every pod on the cluster is Running with all
// containers ready, or has Succeeded.
func WaitForAllPodsHealthy(ctx context.Context, c client.Client, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for all workload cluster pods to be healthy (timeout %s)", timeout))

	// Keyed by pod+reason so a reason that keeps recurring is only tolerated for
	// stuckWaitGrace from when it was first observed.
	firstSeen := map[string]time.Time{}

	Eventually(func(g Gomega) {
		pods := &corev1.PodList{}
		g.Expect(c.List(ctx, pods)).To(Succeed())
		g.Expect(pods.Items).ToNot(BeEmpty(), "no pods found on the workload cluster")

		var unhealthy []string
		for i := range pods.Items {
			pod := &pods.Items[i]
			id := pod.Namespace + "/" + pod.Name

			if pod.DeletionTimestamp != nil || pod.Status.Phase == corev1.PodSucceeded {
				continue
			}

			for _, cs := range allContainerStatuses(pod) {
				if cs.RestartCount > 0 {
					GinkgoWriter.Printf("  pod/%s container %s restarts=%d\n", id, cs.Name, cs.RestartCount)
				}
				w := cs.State.Waiting
				if w == nil {
					continue
				}
				if slices.Contains(terminalWaitReasons, w.Reason) {
					StopTrying(fmt.Sprintf("pod/%s container %s is in %s: %s", id, cs.Name, w.Reason, w.Message)).Now()
				}
				if slices.Contains(stuckWaitReasons, w.Reason) {
					key := id + "/" + w.Reason
					if _, ok := firstSeen[key]; !ok {
						firstSeen[key] = time.Now()
					}
					if stuck := time.Since(firstSeen[key]); stuck > stuckWaitGrace {
						StopTrying(fmt.Sprintf("pod/%s container %s stuck in %s for %s: %s",
							id, cs.Name, w.Reason, stuck.Round(time.Second), w.Message)).Now()
					}
				}
			}

			if pod.Status.Phase != corev1.PodRunning {
				unhealthy = append(unhealthy, fmt.Sprintf("pod/%s phase=%s", id, pod.Status.Phase))
				continue
			}
			// Init containers are excluded: a completed one reports ready=false.
			for _, cs := range pod.Status.ContainerStatuses {
				if !cs.Ready {
					unhealthy = append(unhealthy, fmt.Sprintf("pod/%s container %s not ready (%s)",
						id, cs.Name, containerStateReason(cs)))
				}
			}
		}

		g.Expect(unhealthy).To(BeEmpty(), "unhealthy pods:\n  %s", strings.Join(unhealthy, "\n  "))
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// ExpectWorkloadComponentsRunning asserts that every named component has at
// least one ready pod, matching pods by name prefix.
func ExpectWorkloadComponentsRunning(ctx context.Context, c client.Client, components []string, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for workload components %v to be ready (timeout %s)", components, timeout))

	Eventually(func(g Gomega) {
		pods := &corev1.PodList{}
		g.Expect(c.List(ctx, pods)).To(Succeed())

		var missing []string
		for _, component := range components {
			found := false
			for i := range pods.Items {
				pod := &pods.Items[i]
				if !strings.HasPrefix(pod.Name, component) || pod.Status.Phase != corev1.PodRunning {
					continue
				}
				if allContainersReady(pod) {
					found = true
					break
				}
			}
			if !found {
				missing = append(missing, component)
			}
		}

		g.Expect(missing).To(BeEmpty(), "components with no ready pod: %s", strings.Join(missing, ", "))
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// DumpClusterState writes management and workload cluster state to dir. Failures
// to collect are reported but never fail the spec — this runs after something
// has already gone wrong.
//
// tinkKubeconfig is empty in colocated mode, where the Tinkerbell and BMC
// objects live in the management cluster instead of a cluster of their own.
func DumpClusterState(ctx context.Context, dir, mgmtKubeconfig, tinkKubeconfig, workloadKubeconfig string) {
	if dir == "" {
		return
	}
	By(fmt.Sprintf("Dumping cluster state to %s", dir))

	if mgmtKubeconfig != "" {
		kubectlDump(ctx, mgmtKubeconfig, filepath.Join(dir, "capi-objects.yaml"),
			"get", "cluster,machine,machineset,machinedeployment,kubeadmcontrolplane,tinkerbellcluster,tinkerbellmachine",
			"-A", "-o", "yaml")
		kubectlDump(ctx, mgmtKubeconfig, filepath.Join(dir, "mgmt-pods.yaml"),
			"get", "pods", "-A", "-o", "yaml")
	}

	if tink := firstNonEmpty(tinkKubeconfig, mgmtKubeconfig); tink != "" {
		dumpTinkerbellState(ctx, dir, tink)
	}

	if workloadKubeconfig == "" {
		return
	}
	kubectlDump(ctx, workloadKubeconfig, filepath.Join(dir, "workload-pods.yaml"),
		"get", "pods", "-A", "-o", "yaml")
	kubectlDump(ctx, workloadKubeconfig, filepath.Join(dir, "workload-nodes.yaml"),
		"get", "nodes", "-o", "yaml")
	kubectlDump(ctx, workloadKubeconfig, filepath.Join(dir, "workload-events.txt"),
		"get", "events", "-A", "--sort-by", ".lastTimestamp")
}

// dumpTinkerbellState collects the objects that carry the reason for a
// provisioning failure. A Workflow's BootJobFailed condition says only "job
// failed"; the reason is on the bmc Task, and which provider bmclib chose and
// why it could not connect appears only in the controller log.
func dumpTinkerbellState(ctx context.Context, dir, kubeconfig string) {
	kubectlDump(ctx, kubeconfig, filepath.Join(dir, "tink-objects.yaml"),
		"get", "workflows.tinkerbell.org,hardware.tinkerbell.org,jobs.bmc.tinkerbell.org,tasks.bmc.tinkerbell.org,machines.bmc.tinkerbell.org",
		"-A", "-o", "yaml")
	kubectlDump(ctx, kubeconfig, filepath.Join(dir, "tink-events.txt"),
		"get", "events", "-A", "--sort-by", ".lastTimestamp")
	kubectlDump(ctx, kubeconfig, filepath.Join(dir, "tink-controller.log"),
		"logs", "-n", "tinkerbell", "-l", "stack=tinkerbell",
		"--all-containers", "--tail", "-1", "--prefix")
}

// DumpVirtualBMCLogs writes the vBMC container's log to dir. The BMC lives in a
// container rather than the cluster, so a failed power or virtual-media action
// leaves no trace in any kubeconfig.
func DumpVirtualBMCLogs(ctx context.Context, dir, container string) {
	if dir == "" || container == "" {
		return
	}
	cmd := exec.CommandContext(ctx, "docker", "logs", "--tail", "500", container)
	out, err := cmd.CombinedOutput()
	if err != nil {
		GinkgoWriter.Printf("docker logs %s failed: %v\n", container, err)
	}
	if err := os.WriteFile(filepath.Join(dir, "vbmc.log"), out, 0o600); err != nil {
		GinkgoWriter.Printf("failed writing vbmc.log: %v\n", err)
	}
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// virtualBMCContainer reads the vBMC container name out of the playground's
// state file. Returns empty on any failure so a dump never breaks a teardown.
func virtualBMCContainer(stateFilePath string) string {
	if stateFilePath == "" {
		return ""
	}
	data, err := os.ReadFile(stateFilePath)
	if err != nil {
		GinkgoWriter.Printf("reading %s for vbmc container name: %v\n", stateFilePath, err)
		return ""
	}
	var state struct {
		VirtualBMC struct {
			ContainerName string `yaml:"containerName"`
		} `yaml:"virtualBMC"`
	}
	if err := yaml.Unmarshal(data, &state); err != nil {
		GinkgoWriter.Printf("parsing %s for vbmc container name: %v\n", stateFilePath, err)
		return ""
	}
	return state.VirtualBMC.ContainerName
}

// machineCounts reads the node counts out of the playground's state file. A
// supplied --config can ask for counts the suite's own config knows nothing
// about, and it is the built playground the assertions have to match.
func machineCounts(stateFilePath string) (controlPlanes, workers int, ok bool) {
	if stateFilePath == "" {
		return 0, 0, false
	}
	data, err := os.ReadFile(stateFilePath)
	if err != nil {
		GinkgoWriter.Printf("reading %s for machine counts: %v\n", stateFilePath, err)
		return 0, 0, false
	}
	var state struct {
		Counts struct {
			ControlPlanes int `yaml:"controlPlanes"`
			Workers       int `yaml:"workers"`
		} `yaml:"counts"`
	}
	if err := yaml.Unmarshal(data, &state); err != nil {
		GinkgoWriter.Printf("parsing %s for machine counts: %v\n", stateFilePath, err)
		return 0, 0, false
	}
	// Spares are built but never join, so they are deliberately not counted.
	if state.Counts.ControlPlanes < 1 {
		return 0, 0, false
	}
	return state.Counts.ControlPlanes, state.Counts.Workers, true
}

func kubectlDump(ctx context.Context, kubeconfig, dest string, args ...string) {
	cmd := exec.CommandContext(ctx, "kubectl", append([]string{"--kubeconfig", kubeconfig}, args...)...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		GinkgoWriter.Printf("kubectl %s failed: %v\n", strings.Join(args, " "), err)
	}
	if err := os.WriteFile(dest, out, 0o600); err != nil {
		GinkgoWriter.Printf("failed writing %s: %v\n", dest, err)
	}
}

// listKind lists all objects of a GroupKind in ns, resolving the served version
// through the RESTMapper.
func listKind(ctx context.Context, g Gomega, c client.Client, group, kind, ns string) []unstructured.Unstructured {
	mapping, err := c.RESTMapper().RESTMapping(schema.GroupKind{Group: group, Kind: kind})
	g.Expect(err).ToNot(HaveOccurred(), "resolving %s.%s", kind, group)

	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(mapping.GroupVersionKind.GroupVersion().WithKind(kind + "List"))
	g.Expect(c.List(ctx, list, client.InNamespace(ns))).To(Succeed(), "listing %s in %s", kind, ns)

	return list.Items
}

// expectNoTerminalFailure abandons the wait when an object reports a failure that
// does not clear on its own.
func expectNoTerminalFailure(obj unstructured.Unstructured) {
	id := strings.ToLower(obj.GetKind()) + "/" + obj.GetName()
	if reason := nestedString(obj, "status", "failureReason"); reason != "" {
		StopTrying(fmt.Sprintf("%s failed: %s: %s", id, reason, nestedString(obj, "status", "failureMessage"))).Now()
	}
	if msg := nestedString(obj, "status", "failureMessage"); msg != "" {
		StopTrying(fmt.Sprintf("%s failed: %s", id, msg)).Now()
	}
	if phase := nestedString(obj, "status", "phase"); phase == "Failed" {
		StopTrying(fmt.Sprintf("%s is in phase Failed", id)).Now()
	}
}

// expectConditionTrue asserts that the first alias the object actually reports is
// True. CAPI renamed several conditions between v1beta1 and v1beta2, so both
// spellings are accepted.
func expectConditionTrue(g Gomega, obj unstructured.Unstructured, aliases ...string) {
	id := strings.ToLower(obj.GetKind()) + "/" + obj.GetName()
	for _, condType := range aliases {
		status := conditionStatus(obj, condType)
		if status == "" {
			continue
		}
		g.Expect(status).To(Equal("True"), "%s condition %s is %s", id, condType, status)
		return
	}
	g.Expect(aliases).To(BeEmpty(), "%s reports none of the conditions %v", id, aliases)
}

func conditionStatus(obj unstructured.Unstructured, condType string) string {
	conditions, found, err := unstructured.NestedSlice(obj.Object, "status", "conditions")
	if err != nil || !found {
		return ""
	}
	for _, raw := range conditions {
		cond, ok := raw.(map[string]any)
		if !ok {
			continue
		}
		if t, _ := cond["type"].(string); t != condType {
			continue
		}
		status, _ := cond["status"].(string)
		return status
	}
	return ""
}

func nestedString(obj unstructured.Unstructured, fields ...string) string {
	v, found, err := unstructured.NestedString(obj.Object, fields...)
	if err != nil || !found {
		return ""
	}
	return v
}

func nestedInt(obj unstructured.Unstructured, fields ...string) int64 {
	v, found, err := unstructured.NestedInt64(obj.Object, fields...)
	if err != nil || !found {
		return 0
	}
	return v
}

func nestedBool(obj unstructured.Unstructured, fields ...string) bool {
	v, found, err := unstructured.NestedBool(obj.Object, fields...)
	if err != nil || !found {
		return false
	}
	return v
}

func allContainerStatuses(pod *corev1.Pod) []corev1.ContainerStatus {
	statuses := make([]corev1.ContainerStatus, 0, len(pod.Status.InitContainerStatuses)+len(pod.Status.ContainerStatuses))
	statuses = append(statuses, pod.Status.InitContainerStatuses...)
	return append(statuses, pod.Status.ContainerStatuses...)
}

func allContainersReady(pod *corev1.Pod) bool {
	for _, cs := range pod.Status.ContainerStatuses {
		if !cs.Ready {
			return false
		}
	}
	return len(pod.Status.ContainerStatuses) > 0
}

func containerStateReason(cs corev1.ContainerStatus) string {
	switch {
	case cs.State.Waiting != nil:
		return "Waiting: " + cs.State.Waiting.Reason
	case cs.State.Terminated != nil:
		return "Terminated: " + cs.State.Terminated.Reason
	default:
		return "Running"
	}
}
