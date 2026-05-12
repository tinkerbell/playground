// Package e2e provides end-to-end tests for CAPT playground provisioning.
package e2e

import (
	"flag"
	"fmt"
	"os"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	tinkv1 "github.com/tinkerbell/tinkerbell/api/v1alpha1/tinkerbell"
	"gopkg.in/yaml.v3"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/scheme"
)

// E2EConfig holds test intervals and variables loaded from the e2e config YAML.
type E2EConfig struct {
	Intervals map[string][]string   `yaml:"intervals"`
	Variables map[string]string     `yaml:"variables"`
}

// GetInterval returns parsed timeout and polling durations for a key.
// Returns zero values if the key is missing or unparseable.
func (c *E2EConfig) GetInterval(key string) (timeout, interval time.Duration) {
	if c == nil {
		return 0, 0
	}
	vals, ok := c.Intervals[key]
	if !ok || len(vals) < 2 {
		return 0, 0
	}
	t, err1 := time.ParseDuration(vals[0])
	i, err2 := time.ParseDuration(vals[1])
	if err1 != nil || err2 != nil {
		return 0, 0
	}
	return t, i
}

var (
	e2eConfigPath string
	artifactsDir  string

	mgmtKubeconfig     string
	tinkKubeconfig     string
	workloadKubeconfig string
	namespace          string

	e2eConfig *E2EConfig

	mgmtClient     client.Client
	tinkClient     client.Client
	workloadClient client.Client
)

func init() {
	flag.StringVar(&e2eConfigPath, "e2e.config", "", "Path to the E2E config YAML")
	flag.StringVar(&artifactsDir, "e2e.artifacts", os.TempDir(), "Directory for test artifacts")
	flag.StringVar(&mgmtKubeconfig, "e2e.mgmt-kubeconfig", os.Getenv("E2E_MGMT_KUBECONFIG"), "Management cluster kubeconfig")
	flag.StringVar(&tinkKubeconfig, "e2e.tink-kubeconfig", os.Getenv("E2E_TINK_KUBECONFIG"), "Tinkerbell cluster kubeconfig (external mode)")
	flag.StringVar(&workloadKubeconfig, "e2e.workload-kubeconfig", os.Getenv("E2E_WORKLOAD_KUBECONFIG"), "Workload cluster kubeconfig")
	flag.StringVar(&namespace, "e2e.namespace", os.Getenv("E2E_NAMESPACE"), "Namespace for Tinkerbell resources")
}

func TestE2E(t *testing.T) {
	if mgmtKubeconfig == "" {
		t.Skip("set E2E_MGMT_KUBECONFIG or pass -e2e.mgmt-kubeconfig to run E2E tests")
	}
	RegisterFailHandler(Fail)
	RunSpecs(t, "CAPT Playground E2E Suite")
}

func newScheme() *runtime.Scheme {
	s := runtime.NewScheme()
	Expect(clientgoscheme.AddToScheme(s)).To(Succeed())

	// Register Tinkerbell v1alpha1 types (Workflow, Hardware, Template, etc.)
	sb := &scheme.Builder{GroupVersion: schema.GroupVersion{Group: "tinkerbell.org", Version: "v1alpha1"}}
	sb.Register(&tinkv1.Workflow{}, &tinkv1.WorkflowList{})
	sb.Register(&tinkv1.Hardware{}, &tinkv1.HardwareList{})
	sb.Register(&tinkv1.Template{}, &tinkv1.TemplateList{})
	Expect(sb.AddToScheme(s)).To(Succeed())

	return s
}

func clientFromKubeconfig(kubeconfigPath string, s *runtime.Scheme) (client.Client, error) {
	cfg, err := clientcmd.BuildConfigFromFlags("", kubeconfigPath)
	if err != nil {
		return nil, fmt.Errorf("building config from %s: %w", kubeconfigPath, err)
	}
	return client.New(cfg, client.Options{Scheme: s})
}

var _ = SynchronizedBeforeSuite(func() []byte {
	Expect(mgmtKubeconfig).ToNot(BeEmpty(), "management kubeconfig is required (--e2e.mgmt-kubeconfig or E2E_MGMT_KUBECONFIG)")
	Expect(workloadKubeconfig).ToNot(BeEmpty(), "workload kubeconfig is required (--e2e.workload-kubeconfig or E2E_WORKLOAD_KUBECONFIG)")

	if namespace == "" {
		namespace = "tinkerbell"
	}

	if e2eConfigPath != "" {
		data, err := os.ReadFile(e2eConfigPath)
		Expect(err).ToNot(HaveOccurred(), "failed to read e2e config %s", e2eConfigPath)
		e2eConfig = &E2EConfig{}
		Expect(yaml.Unmarshal(data, e2eConfig)).To(Succeed(), "failed to parse e2e config")
	}

	s := newScheme()

	var err error
	mgmtClient, err = clientFromKubeconfig(mgmtKubeconfig, s)
	Expect(err).ToNot(HaveOccurred(), "failed to create management cluster client")

	// Tinkerbell client: use separate kubeconfig in external mode, else same as mgmt.
	if tinkKubeconfig != "" {
		tinkClient, err = clientFromKubeconfig(tinkKubeconfig, s)
		Expect(err).ToNot(HaveOccurred(), "failed to create tinkerbell cluster client")
	} else {
		tinkClient = mgmtClient
	}

	workloadClient, err = clientFromKubeconfig(workloadKubeconfig, s)
	Expect(err).ToNot(HaveOccurred(), "failed to create workload cluster client")

	return nil
}, func(_ []byte) {})

var _ = SynchronizedAfterSuite(func() {}, func() {
	if artifactsDir != "" {
		By(fmt.Sprintf("Test artifacts saved to %s", artifactsDir))
	}
})
