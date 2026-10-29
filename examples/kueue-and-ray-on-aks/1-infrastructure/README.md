# Module 1 — Prepare managed infrastructure

Use the **managed KubeRay and Kueue extensions** for these examples. Select an
AKS target with no self-installed Kueue or KubeRay controllers, prepare its
capacity, and install the managed operators before configuring queues.

1. Follow [Managed setup](managed/) for prerequisites, the executable extension
   installer, and storage/workload identity preparation.
2. Complete [dataset preparation](managed/data.md) for the workload you choose.
3. Continue to [Module 2 — Queues](../2-kueue-queues/) after the platform and
   workload dependencies pass their verification checks.

The managed extensions supply the operators and supported APIs. You still
configure the Ray runtime images, application code, queue policies, storage,
and workload identity. Operator readiness alone doesn't create datasets or
authorize application access to them.
