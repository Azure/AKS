"""
Image classification test for e2e validation.
Adapted from aks-unbounded/ray/inference_job.py.

Uses a locally-constructed model with random weights instead of downloading from
HuggingFace. This avoids network dependencies (SSL proxy issues, rate limits) while
still exercising the full Ray Data distributed inference pipeline:
  - ActorPoolStrategy distributes work across workers
  - Each actor loads a model, processes batches, returns predictions
  - Ray Data orchestrates the dataflow end-to-end

Auto-detects GPU: if torch.cuda.is_available(), actors declare num_gpus=1 and the
model runs on CUDA; otherwise falls back to CPU. Ray Data infers actor count from
the ActorPoolStrategy size; the cluster must have enough GPU/CPU quota to schedule.
"""
import ray
import numpy as np

ray.init()
cluster_resources = ray.cluster_resources()
print(f"Cluster resources: {cluster_resources}")
GPU_AVAILABLE = cluster_resources.get("GPU", 0) > 0
print(f"GPU_AVAILABLE = {GPU_AVAILABLE}")

# Generate synthetic images in-memory (no S3 dependency)
NUM_IMAGES = 10
synthetic_images = [
    {"image": np.random.randint(0, 255, (224, 224, 3), dtype=np.uint8)}
    for _ in range(NUM_IMAGES)
]

ds = ray.data.from_items(synthetic_images)

LABELS = ["cat", "dog", "bird", "fish", "car"]

class ImageClassifier:
    def __init__(self):
        import torch
        import torch.nn as nn

        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Device: {self.device}")
        # Simple conv net with random weights — no download needed.
        self.model = nn.Sequential(
            nn.Conv2d(3, 16, 3, stride=2),
            nn.ReLU(),
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(16, len(LABELS)),
        ).to(self.device)
        self.model.eval()
        print("Model loaded successfully")

    def __call__(self, batch):
        import torch

        images = torch.from_numpy(
            np.stack(batch["image"])
        ).permute(0, 3, 1, 2).float().to(self.device) / 255.0

        with torch.no_grad():
            logits = self.model(images)
            indices = logits.argmax(dim=1)

        batch["label"] = [LABELS[i] for i in indices.tolist()]
        batch["score"] = [logits[j, indices[j]].item() for j in range(len(indices))]
        return batch

# Use fewer actors on GPU (1 worker × 1 GPU) than CPU (2 workers × 2 CPU).
POOL_SIZE = 1 if GPU_AVAILABLE else 2

predictions = ds.map_batches(
    ImageClassifier,
    compute=ray.data.ActorPoolStrategy(size=POOL_SIZE),
    batch_size=4,
    **({"num_gpus": 1} if GPU_AVAILABLE else {}),
)

results = predictions.take_all()
print(f"\nInference complete: {len(results)} images classified")
for i, r in enumerate(results):
    print(f"  Image {i}: Label: {r['label']} (score: {r['score']:.4f})")

print("\nSUCCESS: All images classified")

