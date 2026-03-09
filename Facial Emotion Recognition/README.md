# Facial Emotion Recognition using CNN

A Convolutional Neural Network (CNN) based Facial Emotion Recognition system trained on the FER2013 dataset. This project classifies facial expressions into seven distinct emotions:

- 😡 **Angry**
- 🤢 **Disgust**
- 😨 **Fear**
- 😄 **Happy**
- 😐 **Neutral**
- 😢 **Sad**
- 😲 **Surprise**

## Dataset

- **FER2013**: [Download from Kaggle](https://www.kaggle.com/datasets/msambare/fer2013)

### Directory Structure

Organize your dataset as follows:

```
data/
├── train/
│   ├── Angry
│   ├── Disgust
│   ├── Fear
│   ├── Happy
│   ├── Neutral
│   ├── Sad
│   └── Surprise
└── test/
    ├── Angry
    ├── Disgust
    ├── Fear
    ├── Happy
    ├── Neutral
    ├── Sad
    └── Surprise
```

## Setup and Installation

1. Clone this repository:

```bash
git clone <your-repository-link>
cd <your-repo-directory>
```

2. Install dependencies:

```bash
pip install tensorflow keras numpy opencv-python
```

## Project Files

- `main.py`: Trains and saves the CNN model (`emotion_recognition_model.h5`).
- `test.py`: Real-time emotion recognition using webcam.
- `testdata.py`: Emotion detection from a static image (`pic3.jpg`).

### Training the Model

Run the following command to train the model:

```bash
python main.py
```

### Running Real-time Webcam Emotion Recognition

Make sure your webcam is enabled:

```bash
python test.py
```

### Running Emotion Recognition on a Single Image

Place the image (`pic3.jpg`) in the project directory and run:

```bash
python testdata.py
```

## Project Architecture

The CNN architecture includes:

- Convolutional Layers
- MaxPooling Layers
- Dropout for Regularization
- Dense (Fully Connected) Layers

## Technologies Used

- Python
- TensorFlow/Keras
- OpenCV
