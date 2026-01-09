import cv2
import numpy as np
import time
import torch
import torch.nn as nn
import torchvision.transforms as transforms
from torchvision.models import mobilenet_v3_small
from PIL import Image
from collections import Counter

class TrashDetector:
    def __init__(self, checkpoint_path="best_model_finetune.pth"):
        self.device = torch.device("cpu")
        self.labels = ['cardboard', 'glass', 'metal', 'paper', 'plastic', 'trash']
        self.confidence_threshold = 0.60
        self.model = self.load_model(checkpoint_path, len(self.labels))
        
        # Preprocessing
        self.preprocess = transforms.Compose([
            transforms.CenterCrop((480, 480)),
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

    def load_model(self, path, num_classes):
        print(f"[Vision] Loading model from {path}...")
        model = mobilenet_v3_small(weights=None)
        in_features = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(in_features, num_classes)
        try:
            model.load_state_dict(torch.load(path, map_location=self.device))
        except FileNotFoundError:
            print(f"[Vision] ERROR: Checkpoint not found at {path}")
            exit()
        except RuntimeError as e:
            print(f"[Vision] ERROR: Model mismatch! {e}")
            exit()
        model.to(self.device)
        model.eval()
        return model

    def detect(self, image: Image):
        input_tensor = self.preprocess(image).unsqueeze(0).to(self.device)
        with torch.no_grad():
            outputs = self.model(input_tensor)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)[0]
            top_prob, top_catid = torch.max(probabilities, 0)
            confidence = top_prob.item()
            predicted_label = self.labels[top_catid.item()]
        
            return confidence, predicted_label
            
        