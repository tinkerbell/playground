package e2e

import (
	"context"
	"fmt"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	tinkv1 "github.com/tinkerbell/tinkerbell/api/v1alpha1/tinkerbell"
	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// WaitForWorkflowsSuccess polls Workflow CRs until all reach SUCCESS state.
// Fails fast if any workflow reaches FAILED or TIMEOUT.
func WaitForWorkflowsSuccess(ctx context.Context, c client.Client, ns string, expectedCount int, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for %d workflow(s) in %s to reach SUCCESS (timeout %s)", expectedCount, ns, timeout))

	Eventually(func(g Gomega) {
		wfList := &tinkv1.WorkflowList{}
		g.Expect(c.List(ctx, wfList, client.InNamespace(ns))).To(Succeed())

		// Workflows may not exist yet while CAPT reconciles. Keep polling.
		g.Expect(len(wfList.Items)).To(BeNumerically(">=", expectedCount),
			"waiting for %d workflows, currently %d", expectedCount, len(wfList.Items))

		for _, wf := range wfList.Items {
			state := wf.Status.State
			GinkgoWriter.Printf("  workflow/%s state=%s\n", wf.Name, state)
			g.Expect(state).ToNot(Equal(tinkv1.WorkflowStateFailed),
				"workflow %s failed", wf.Name)
			g.Expect(state).ToNot(Equal(tinkv1.WorkflowStateTimeout),
				"workflow %s timed out", wf.Name)
			g.Expect(state).To(Equal(tinkv1.WorkflowStateSuccess),
				"workflow %s in state %s, want SUCCESS", wf.Name, state)
		}
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// WaitForAllNodesReady waits for the expected number of nodes to be Ready
// on the workload cluster.
func WaitForAllNodesReady(ctx context.Context, c client.Client, expectedCount int, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for %d node(s) to be Ready (timeout %s)", expectedCount, timeout))

	Eventually(func(g Gomega) {
		nodeList := &corev1.NodeList{}
		g.Expect(c.List(ctx, nodeList)).To(Succeed())
		g.Expect(nodeList.Items).To(HaveLen(expectedCount), "expected %d nodes, got %d", expectedCount, len(nodeList.Items))

		for _, node := range nodeList.Items {
			ready := false
			for _, cond := range node.Status.Conditions {
				if cond.Type == corev1.NodeReady && cond.Status == corev1.ConditionTrue {
					ready = true
					break
				}
			}
			g.Expect(ready).To(BeTrue(), "node %s is not Ready", node.Name)
		}
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// WaitForAPIServerReady polls the workload cluster API server until it responds.
func WaitForAPIServerReady(kubeconfigPath string, timeout, interval time.Duration) {
	By(fmt.Sprintf("Waiting for workload API server to be reachable (timeout %s)", timeout))

	Eventually(func(g Gomega) {
		cmd := exec.CommandContext(context.TODO(),
			"kubectl", "--kubeconfig", kubeconfigPath,
			"get", "--raw", "/readyz",
		)
		out, err := cmd.CombinedOutput()
		g.Expect(err).ToNot(HaveOccurred(), "API server not ready: %s", string(out))
	}).WithTimeout(timeout).WithPolling(interval).Should(Succeed())
}

// DeployCNI applies kube-router to the workload cluster so nodes can reach Ready.
func DeployCNI(kubeconfigPath string) {
	By("Deploying kube-router CNI")
	cmd := exec.CommandContext(context.TODO(),
		"kubectl", "--kubeconfig", kubeconfigPath,
		"apply", "-f", "https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml",
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		GinkgoWriter.Printf("CNI apply output:\n%s\n", string(out))
	}
	Expect(err).ToNot(HaveOccurred(), "failed to deploy kube-router CNI")
}

// ListWorkflows prints all workflows in the namespace for debugging.
func ListWorkflows(ctx context.Context, c client.Client, ns string) {
	wfList := &tinkv1.WorkflowList{}
	if err := c.List(ctx, wfList, client.InNamespace(ns)); err != nil {
		GinkgoWriter.Printf("Failed to list workflows: %v\n", err)
		return
	}
	for _, wf := range wfList.Items {
		GinkgoWriter.Printf("  workflow/%s state=%s\n", wf.Name, wf.Status.State)
	}
}

// ListHardware prints all hardware in the namespace for debugging.
func ListHardware(ctx context.Context, c client.Client, ns string) {
	hwList := &tinkv1.HardwareList{}
	if err := c.List(ctx, hwList, client.InNamespace(ns)); err != nil {
		GinkgoWriter.Printf("Failed to list hardware: %v\n", err)
		return
	}
	for _, hw := range hwList.Items {
		GinkgoWriter.Printf("  hardware/%s\n", hw.Name)
	}
}
