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
		capiTimeout      = 15 * time.Minute
		capiInterval     = 15 * time.Second
		podTimeout       = 10 * time.Minute
		podInterval      = 10 * time.Second
		controlPlanes    = 1
		workers          = 1
		expectedNodes    = 2
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
		if t, i := e2eConfig.GetInterval("default/wait-capi-ready"); t > 0 {
			capiTimeout = t
			capiInterval = i
		}
		if t, i := e2eConfig.GetInterval("default/wait-pods"); t > 0 {
			podTimeout = t
			podInterval = i
		}
		controlPlanes = e2eConfig.GetVariableInt("CONTROL_PLANE_MACHINE_COUNT", controlPlanes)
		workers = e2eConfig.GetVariableInt("WORKER_MACHINE_COUNT", workers)
		// Outranks the suite's config, which is fixed at 1+1 and says nothing
		// about a playground built from a supplied --config.
		if cp, w, ok := machineCounts(stateFile); ok {
			controlPlanes, workers = cp, w
		}
		expectedNodes = controlPlanes + workers
	})

	AfterEach(func(ctx SpecContext) {
		if CurrentSpecReport().Failed() {
			DumpClusterState(ctx, artifactsDir, mgmtKubeconfig, tinkKubeconfig, workloadKubeconfig)
			DumpVirtualBMCLogs(ctx, artifactsDir, virtualBMCContainer(stateFile))
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
		DeployCNI(ctx, cniScript, stateFile, workloadKubeconfig)
	}, SpecTimeout(5*time.Minute))

	It("has all nodes Ready after CNI deployment", func(ctx SpecContext) {
		WaitForAllNodesReady(ctx, workloadClient, expectedNodes, nodeTimeout, nodeInterval)
	}, SpecTimeout(15*time.Minute))

	Context("cluster health", Label("health"), func() {
		It("reports all CAPI and CAPT objects ready", func(ctx SpecContext) {
			WaitForCAPIReady(ctx, mgmtClient, namespace, controlPlanes, workers, capiTimeout, capiInterval)
		}, SpecTimeout(20*time.Minute))

		It("has all workload cluster pods healthy", func(ctx SpecContext) {
			WaitForAllPodsHealthy(ctx, workloadClient, podTimeout, podInterval)
		}, SpecTimeout(15*time.Minute))

		It("has every required workload component running", func(ctx SpecContext) {
			ExpectWorkloadComponentsRunning(ctx, workloadClient, requiredWorkloadComponents, podTimeout, podInterval)
		}, SpecTimeout(15*time.Minute))
	})
})
