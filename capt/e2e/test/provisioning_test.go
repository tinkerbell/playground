package e2e

import (
	"time"

	. "github.com/onsi/ginkgo/v2"
)

var _ = Describe("Workload cluster provisioning", Label("provisioning"), Ordered, func() {
	var (
		workflowTimeout  = 25 * time.Minute
		workflowInterval = 10 * time.Second
		nodeTimeout      = 10 * time.Minute
		nodeInterval     = 10 * time.Second
		expectedNodes    = 2 // 1 control plane + 1 worker
	)

	// Override from E2E config if loaded.
	BeforeAll(func() {
		if t, i := e2eConfig.GetInterval("default/wait-workflow"); t > 0 {
			workflowTimeout = t
			workflowInterval = i
		}
		if t, i := e2eConfig.GetInterval("default/wait-nodes"); t > 0 {
			nodeTimeout = t
			nodeInterval = i
		}
	})

	AfterAll(func(ctx SpecContext) {
		By("Dumping workflows and hardware for debugging")
		ListWorkflows(ctx, tinkClient, namespace)
		ListHardware(ctx, tinkClient, namespace)
	})

	It("completes all workflows successfully", func(ctx SpecContext) {
		WaitForWorkflowsSuccess(ctx, tinkClient, namespace, expectedNodes, workflowTimeout, workflowInterval)
	}, SpecTimeout(30*time.Minute))

	It("has a reachable workload API server", func(ctx SpecContext) {
		WaitForAPIServerReady(ctx, workloadKubeconfig, nodeTimeout, 10*time.Second)
	}, SpecTimeout(15*time.Minute))

	It("deploys CNI to the workload cluster", func(ctx SpecContext) {
		DeployCNI(ctx, workloadKubeconfig)
	}, SpecTimeout(5*time.Minute))

	It("has all nodes Ready after CNI deployment", func(ctx SpecContext) {
		WaitForAllNodesReady(ctx, workloadClient, expectedNodes, nodeTimeout, nodeInterval)
	}, SpecTimeout(15*time.Minute))
})
