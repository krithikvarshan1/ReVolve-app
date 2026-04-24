from __future__ import annotations

import os
import pickle
import re
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

import joblib
import numpy as np
import torch
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


MODEL_DIR = Path(__file__).resolve().parent.parent / "models_ml"
LOGGER = logging.getLogger(__name__)


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_env_file(Path(__file__).resolve().parent / ".env")
_load_env_file(Path(__file__).resolve().parent.parent / ".env")


class SensorInput(BaseModel):
    temperature: float = Field(..., description="Temperature in Celsius")
    vibration: float = Field(..., description="Vibration in g")
    current: float = Field(..., description="Current in amperes")
    gas: float = Field(..., description="Gas concentration in ppm")
    dust: float = Field(0.0, description="Dust concentration ug/m3")
    sound: float = Field(0.0, description="Sound in dB")
    deviceId: str | None = None


class PredictiveResponse(BaseModel):
    fault_prediction: str
    fault_confidence: float
    remaining_useful_life: int
    anomaly_status: str
    future_forecast_temp: float
    maintenance_recommendation: str
    health_score: int
    risk_level: str
    forecast_series: list[float] = []


class ChatRequest(BaseModel):
    query: str = Field(..., min_length=2, description="User chat query")


class ChatResponse(BaseModel):
    answer: str
    confidence: float
    suggested_questions: list[str] = []
    source: str = "fallback"


@dataclass
class ModelRegistry:
    fault_model: Any
    rul_model: Any
    anomaly_model: Any
    label_encoder: Any
    lstm_model: Any


MODEL_REGISTRY: ModelRegistry | None = None


CHAT_KNOWLEDGE_BASE: dict[str, dict[str, Any]] = {
    "login": {
        "keywords": ["login", "sign in", "signin", "account", "password", "google", "biometric"],
        "answer": (
            "Use the login page to sign in with email/password, Google sign-in, or biometric login. "
            "If Firebase is not configured, social and biometric options are disabled until setup is complete."
        ),
    },
    "dashboard-overview": {
        "keywords": ["dashboard", "overview", "kpi", "health score", "rul", "risk"],
        "answer": (
            "The Overview section shows live KPIs: health score, failure risk, remaining useful life (RUL), "
            "and usage window. It combines real-time sensor streams with predictive outputs."
        ),
    },
    "alerts": {
        "keywords": ["alert", "alarm", "warning", "critical", "notification"],
        "answer": (
            "The Alert Center lists threshold and predictive alerts. Critical predictive events trigger a high-visibility "
            "snackbar notification in the dashboard."
        ),
    },
    "devices": {
        "keywords": ["device", "relay", "online", "offline", "map", "location"],
        "answer": (
            "The Devices section shows connected hardware status and relay controls. You can select a device, "
            "toggle relay state, and view location on the map panel."
        ),
    },
    "analytics": {
        "keywords": ["analytics", "risk distribution", "anomaly rate", "prediction history", "logs"],
        "answer": (
            "Analytics summarizes historical predictions, anomaly rates, and risk-level distribution for admin review. "
            "You can also inspect logs in the Logs section."
        ),
    },
    "export": {
        "keywords": ["export", "csv", "pdf", "report", "download"],
        "answer": (
            "Use Downloadable Reports in the dashboard to export prediction history as CSV or PDF. "
            "Exports are generated from the latest available prediction rows."
        ),
    },
    "predictive-model": {
        "keywords": ["predictive", "model", "fault", "anomaly", "forecast", "maintenance", "ml"],
        "answer": (
            "ReVolve runs predictive maintenance inference for fault class, confidence, anomaly status, RUL, "
            "forecast temperature, and maintenance recommendation."
        ),
    },
}

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3")


def _ollama_chat_url() -> str:
    return f"{OLLAMA_HOST.rstrip('/')}/api/chat"


def _normalize_chat_text(text: str) -> str:
    lowered = text.lower().strip()
    return re.sub(r"\s+", " ", lowered)


def _find_best_chat_answer(query: str) -> tuple[str, float]:
    normalized = _normalize_chat_text(query)

    best_answer = ""
    best_score = 0
    for topic in CHAT_KNOWLEDGE_BASE.values():
        score = 0
        for keyword in topic["keywords"]:
            if keyword in normalized:
                score += 1

        if score > best_score:
            best_score = score
            best_answer = topic["answer"]

    if best_score == 0:
        return (
            "I can help only with ReVolve app usage, such as login, dashboard sections, devices, alerts, analytics, "
            "predictive outputs, and report export. Try asking about one of these.",
            0.35,
        )

    confidence = min(0.95, 0.45 + best_score * 0.15)
    return best_answer, round(confidence, 2)


def _suggested_questions() -> list[str]:
    return [
        "How do I interpret health score and RUL?",
        "How can I export reports to CSV or PDF?",
        "What does the Alert Center show?",
        "How do relay controls work in Devices?",
    ]


def _app_assistant_system_prompt() -> str:
    return (
        "You are ReVolve app assistant. Only answer questions related to ReVolve app usage, "
        "screens, dashboard sections, alerts, devices, analytics, predictive maintenance outputs, "
        "and report export workflows. "
        "If the user asks out-of-scope questions, clearly say you can only help with ReVolve app usage. "
        "Keep answers concise and practical."
    )


def _is_ollama_available() -> bool:
    endpoint = f"{OLLAMA_HOST.rstrip('/')}/api/tags"
    try:
        req = urlrequest.Request(endpoint, method="GET")
        with urlrequest.urlopen(req, timeout=4):
            return True
    except Exception:
        return False


def _call_chat_api(query: str) -> str:
    endpoint = _ollama_chat_url()
    payload = {
        "model": OLLAMA_MODEL,
        "messages": [
            {"role": "system", "content": _app_assistant_system_prompt()},
            {"role": "user", "content": query},
        ],
        "stream": False,
        "options": {
            "temperature": 0.2,
            "num_predict": 500,
        },
    }

    req = urlrequest.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlrequest.urlopen(req, timeout=20) as response:
            raw = response.read().decode("utf-8")
            body = json.loads(raw)
    except urlerror.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Chat API HTTP error {exc.code}: {detail}") from exc
    except Exception as exc:
        raise RuntimeError(f"Chat API request failed: {exc}") from exc

    content = str(body.get("message", {}).get("content", "")).strip()
    if not content:
        raise RuntimeError("Chat API returned empty content")

    return content


def _load_pickle(path: Path) -> Any:
    try:
        return joblib.load(path)
    except Exception:
        with path.open("rb") as handle:
            return pickle.load(handle)


def _load_lstm_model(path: Path) -> Any:
    try:
        # weights_only=False is required for checkpoints that contain
        # non-tensor objects (e.g. full nn.Module or dict with metadata).
        # PyTorch >= 2.6 changed the default to True which breaks these files.
        checkpoint = torch.load(path, map_location=torch.device("cpu"), weights_only=False)
    except Exception:
        # Fallback for very old torch versions that don't accept weights_only.
        checkpoint = torch.load(path, map_location=torch.device("cpu"))  # type: ignore[call-overload]
    if hasattr(checkpoint, "eval"):
        checkpoint.eval()
    return checkpoint


def _default_feature_order() -> list[str]:
    return [
        "temp",
        "gas",
        "dust",
        "current",
        "sound",
        "mpu_ax",
        "mpu_ay",
        "mpu_az",
        "adxl_x",
        "adxl_y",
        "adxl_z",
        "mpu_a_mag",
        "adxl_a_mag",
        "dt_s",
        "temp_diff",
        "gas_diff",
        "dust_diff",
        "current_diff",
        "sound_diff",
        "mpu_a_mag_diff",
        "adxl_a_mag_diff",
        "temp_roll_mean_10",
        "temp_roll_std_10",
        "gas_roll_mean_10",
        "gas_roll_std_10",
        "dust_roll_mean_10",
        "dust_roll_std_10",
        "current_roll_mean_10",
        "current_roll_std_10",
        "sound_roll_mean_10",
        "sound_roll_std_10",
        "mpu_a_mag_roll_mean_10",
        "mpu_a_mag_roll_std_10",
        "adxl_a_mag_roll_mean_10",
        "adxl_a_mag_roll_std_10",
        "rul_proxy_hours",
    ]


def _engineer_feature_map(sensor: SensorInput) -> dict[str, float]:
    # Sensor input currently does not include MPU/ADXL axes; initialize to neutral values.
    mpu_ax = 0.0
    mpu_ay = 0.0
    mpu_az = 0.0
    adxl_x = 0.0
    adxl_y = 0.0
    adxl_z = 0.0

    mpu_a_mag = float(np.sqrt(mpu_ax**2 + mpu_ay**2 + mpu_az**2))
    adxl_a_mag = float(np.sqrt(adxl_x**2 + adxl_y**2 + adxl_z**2))

    # Use current values as short-window means with zero variance when history is unavailable.
    temp_roll_mean_10 = sensor.temperature
    gas_roll_mean_10 = sensor.gas
    dust_roll_mean_10 = sensor.dust
    current_roll_mean_10 = sensor.current
    sound_roll_mean_10 = sensor.sound

    temp_norm = sensor.temperature / 100.0
    vib_norm = sensor.vibration / 10.0
    current_norm = sensor.current / 15.0
    gas_norm = sensor.gas / 1000.0
    dust_norm = sensor.dust / 500.0
    sound_norm = sensor.sound / 120.0
    health_proxy = max(
        0.0,
        1.0 - (0.3 * temp_norm + 0.25 * vib_norm + 0.2 * current_norm + 0.15 * gas_norm + 0.05 * dust_norm + 0.05 * sound_norm),
    )

    return {
        "temp": sensor.temperature,
        "gas": sensor.gas,
        "dust": sensor.dust,
        "current": sensor.current,
        "sound": sensor.sound,
        "mpu_ax": mpu_ax,
        "mpu_ay": mpu_ay,
        "mpu_az": mpu_az,
        "adxl_x": adxl_x,
        "adxl_y": adxl_y,
        "adxl_z": adxl_z,
        "mpu_a_mag": mpu_a_mag,
        "adxl_a_mag": adxl_a_mag,
        "dt_s": 1.0,
        "temp_diff": 0.0,
        "gas_diff": 0.0,
        "dust_diff": 0.0,
        "current_diff": 0.0,
        "sound_diff": 0.0,
        "mpu_a_mag_diff": 0.0,
        "adxl_a_mag_diff": 0.0,
        "temp_roll_mean_10": temp_roll_mean_10,
        "temp_roll_std_10": 0.0,
        "gas_roll_mean_10": gas_roll_mean_10,
        "gas_roll_std_10": 0.0,
        "dust_roll_mean_10": dust_roll_mean_10,
        "dust_roll_std_10": 0.0,
        "current_roll_mean_10": current_roll_mean_10,
        "current_roll_std_10": 0.0,
        "sound_roll_mean_10": sound_roll_mean_10,
        "sound_roll_std_10": 0.0,
        "mpu_a_mag_roll_mean_10": mpu_a_mag,
        "mpu_a_mag_roll_std_10": 0.0,
        "adxl_a_mag_roll_mean_10": adxl_a_mag,
        "adxl_a_mag_roll_std_10": 0.0,
        "rul_proxy_hours": max(1.0, health_proxy * 2000.0),
    }


def _operational_health_proxy(sensor: SensorInput) -> float:
    temp_norm = sensor.temperature / 100.0
    vib_norm = sensor.vibration / 10.0
    current_norm = sensor.current / 15.0
    gas_norm = sensor.gas / 1000.0
    dust_norm = sensor.dust / 500.0
    sound_norm = sensor.sound / 120.0
    return max(
        0.0,
        1.0 - (0.3 * temp_norm + 0.25 * vib_norm + 0.2 * current_norm + 0.15 * gas_norm + 0.05 * dust_norm + 0.05 * sound_norm),
    )


def _build_feature_vector(sensor: SensorInput, models: ModelRegistry) -> np.ndarray:
    feature_map = _engineer_feature_map(sensor)

    model_feature_names = getattr(models.fault_model, "feature_names_in_", None)
    if model_feature_names is not None:
        ordered_names = [str(name) for name in model_feature_names]
    else:
        ordered_names = _default_feature_order()

    values = [feature_map.get(name, 0.0) for name in ordered_names]
    return np.array([values], dtype=np.float32)


def _expected_feature_count(model: Any) -> int | None:
    expected_count = getattr(model, "n_features_in_", None)
    if expected_count is None and hasattr(model, "get_booster"):
        try:
            expected_count = model.get_booster().num_features()
        except Exception:
            expected_count = None

    if expected_count is not None:
        try:
            return int(expected_count)
        except (TypeError, ValueError):
            return None

    return None


def _align_features_for_model(features: np.ndarray, model: Any) -> np.ndarray:
    expected_count = _expected_feature_count(model)
    if expected_count is None:
        return features

    current_count = int(features.shape[1])
    if current_count == expected_count:
        return features

    if current_count > expected_count:
        return features[:, :expected_count]

    padding = np.zeros(
        (features.shape[0], expected_count - current_count),
        dtype=features.dtype,
    )
    return np.concatenate([features, padding], axis=1)


def _predict_fault(features: np.ndarray, models: ModelRegistry) -> tuple[str, float]:
    model_features = _align_features_for_model(features, models.fault_model)
    raw_prediction = models.fault_model.predict(model_features)[0]

    if hasattr(models.label_encoder, "inverse_transform"):
        decoded = models.label_encoder.inverse_transform([raw_prediction])[0]
    else:
        decoded = str(raw_prediction)

    confidence = 0.0
    if hasattr(models.fault_model, "predict_proba"):
        probs = models.fault_model.predict_proba(model_features)[0]
        confidence = float(np.max(probs) * 100.0)

    return str(decoded).upper(), round(confidence, 2)


def _predict_rul(features: np.ndarray, models: ModelRegistry) -> int:
    model_features = _align_features_for_model(features, models.rul_model)
    raw_value = float(models.rul_model.predict(model_features)[0])
    return _normalize_rul_to_hours(raw_value)


def _normalize_rul_to_hours(raw_value: float) -> int:
    # Some training setups emit normalized RUL in [0, 1]. Convert to hours.
    if 0.0 <= raw_value <= 1.5:
        value = raw_value * 2000.0
    else:
        value = raw_value
    return max(0, int(round(value)))


def _predict_anomaly(features: np.ndarray, models: ModelRegistry) -> str:
    model_features = _align_features_for_model(features, models.anomaly_model)
    raw = models.anomaly_model.predict(model_features)[0]
    if int(raw) in (-1, 1):
        return "ANOMALY" if int(raw) == -1 else "NORMAL"
    return "ANOMALY" if int(raw) == 1 else "NORMAL"


def _predict_forecast(sensor: SensorInput, models: ModelRegistry) -> tuple[float, list[float]]:
    values = np.array(
        [
            sensor.temperature,
            sensor.vibration,
            sensor.current,
            sensor.gas,
            sensor.dust,
            sensor.sound,
        ],
        dtype=np.float32,
    )

    # First try PyTorch nn.Module style inference.
    if hasattr(models.lstm_model, "forward"):
        tensor = torch.tensor(values.reshape(1, 1, -1), dtype=torch.float32)
        with torch.no_grad():
            out = models.lstm_model(tensor)
        arr = np.array(out).reshape(-1)
        series = [float(x) for x in arr[:12]]
        return round(series[0], 3) if series else float(sensor.temperature), series

    # Fallback to sklearn-like predictor serialized as .pth.
    if hasattr(models.lstm_model, "predict"):
        out = models.lstm_model.predict(values.reshape(1, -1))
        arr = np.array(out).reshape(-1)
        series = [float(x) for x in arr[:12]]
        return round(series[0], 3) if series else float(sensor.temperature), series

    # Safe deterministic fallback if model format is unexpected.
    baseline = float(sensor.temperature)
    series = [baseline + i * 0.3 for i in range(12)]
    return round(series[0], 3), [round(x, 3) for x in series]


def _derive_recommendation(fault: str, anomaly: str, risk: str) -> str:
    lookup = {
        "NORMAL": "No Action Needed",
        "DUST_FAULT": "Inspect and replace air filters",
        "OVERHEAT": "Inspect Cooling System",
        "OVERLOAD": "Reduce Load",
        "VIBRATION_FAULT": "Inspect mounts and balance rotating components",
        "BEARING_WEAR": "Schedule bearing inspection and lubrication",
        "FAILURE_IMMINENT": "Immediate Shutdown Required",
    }
    recommendation = lookup.get(fault, "Schedule maintenance inspection")

    if risk == "CRITICAL" and recommendation == "No Action Needed":
        return "Immediate Shutdown Required"

    if anomaly == "ANOMALY" and risk in {"HIGH", "CRITICAL"}:
        return f"{recommendation} (Anomaly escalation)"

    return recommendation


def _fault_severity_weight(fault: str) -> int:
    return {
        "NORMAL": 0,
        "DUST_FAULT": 10,
        "OVERHEAT": 20,
        "OVERLOAD": 25,
        "VIBRATION_FAULT": 25,
        "BEARING_WEAR": 30,
        "FAILURE_IMMINENT": 40,
    }.get(fault, 15)


def _calculate_health_and_risk(
    fault: str,
    fault_confidence: float,
    rul: int,
    anomaly: str,
) -> tuple[int, str]:
    severity = _fault_severity_weight(fault)
    score = 100

    # Weighted confidence penalty makes severe faults degrade health faster.
    confidence_penalty = int(round((fault_confidence / 100.0) * severity * 0.9))
    score -= confidence_penalty

    if anomaly == "ANOMALY":
        score -= 20

    if rul < 50:
        score -= 30
    elif rul < 150:
        score -= 18
    elif rul < 300:
        score -= 8

    # Base severity deduction independent of confidence.
    score -= int(round(severity * 0.5))
    score = max(0, min(100, score))

    risk_score = 0.0
    risk_score += severity
    risk_score += fault_confidence * 0.15

    if anomaly == "ANOMALY":
        risk_score += 20

    if score < 30:
        risk_score += 30
    elif score < 50:
        risk_score += 20
    elif score < 70:
        risk_score += 10

    if rul < 10:
        risk_score += 40
    elif rul < 50:
        risk_score += 30
    elif rul < 100:
        risk_score += 20
    elif rul < 300:
        risk_score += 10

    risk_score = max(0.0, risk_score)

    if risk_score <= 30:
        risk = "LOW"
    elif risk_score <= 60:
        risk = "MEDIUM"
    elif risk_score <= 90:
        risk = "HIGH"
    else:
        risk = "CRITICAL"

    return score, risk


def load_models() -> ModelRegistry:
    fault_model = _load_pickle(MODEL_DIR / "motor_fault_gpu_model.pkl")
    rul_model = _load_pickle(MODEL_DIR / "rul_proxy_model.pkl")
    anomaly_model = _load_pickle(MODEL_DIR / "improved_anomaly_model.pkl")
    label_encoder = _load_pickle(MODEL_DIR / "label_encoder.pkl")
    lstm_model = _load_lstm_model(MODEL_DIR / "lstm_forecast_model.pth")

    return ModelRegistry(
        fault_model=fault_model,
        rul_model=rul_model,
        anomaly_model=anomaly_model,
        label_encoder=label_encoder,
        lstm_model=lstm_model,
    )


from contextlib import asynccontextmanager


@asynccontextmanager
async def _lifespan(application: FastAPI):
    global MODEL_REGISTRY
    try:
        MODEL_REGISTRY = load_models()
        LOGGER.info("ML models loaded successfully from %s", MODEL_DIR)
    except Exception as exc:
        MODEL_REGISTRY = None
        LOGGER.warning("Failed to load ML models from %s: %s", MODEL_DIR, exc)
    yield


app = FastAPI(
    title="ReVolve Predictive Maintenance API",
    version="1.0.0",
    lifespan=_lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8000",
        "http://localhost:53521",
        "http://127.0.0.1:53521",
    ],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



@app.get("/health")
def health() -> dict[str, Any]:
    ollama_ready = _is_ollama_available()
    model_detail: dict[str, str] = {}
    if MODEL_REGISTRY is None:
        model_detail["status"] = "missing"
    else:
        model_detail["status"] = "loaded"
        model_detail["fault_model"] = type(MODEL_REGISTRY.fault_model).__name__
        model_detail["rul_model"] = type(MODEL_REGISTRY.rul_model).__name__
        model_detail["anomaly_model"] = type(MODEL_REGISTRY.anomaly_model).__name__
        model_detail["lstm_model"] = type(MODEL_REGISTRY.lstm_model).__name__
    return {
        "status": "ok",
        "models": model_detail,
        "chat_api": "ollama-active" if ollama_ready else "fallback-mode",
        "chat_model": OLLAMA_MODEL,
        "chat_provider": "ollama",
    }


@app.get("/debug-models")
def debug_models() -> dict[str, Any]:
    """Diagnostic endpoint – shows which models loaded and any errors."""
    results: dict[str, Any] = {"model_dir": str(MODEL_DIR), "files": []}
    for f in MODEL_DIR.iterdir():
        results["files"].append(f.name)

    load_errors: dict[str, str] = {}
    for name, loader in [
        ("motor_fault_gpu_model.pkl", lambda p: _load_pickle(p)),
        ("rul_proxy_model.pkl", lambda p: _load_pickle(p)),
        ("improved_anomaly_model.pkl", lambda p: _load_pickle(p)),
        ("label_encoder.pkl", lambda p: _load_pickle(p)),
        ("lstm_forecast_model.pth", lambda p: _load_lstm_model(p)),
    ]:
        try:
            loader(MODEL_DIR / name)  # type: ignore[operator]
            load_errors[name] = "ok"
        except Exception as exc:
            load_errors[name] = str(exc)

    results["load_results"] = load_errors
    results["registry_loaded"] = MODEL_REGISTRY is not None
    return results

@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "ReVolve Predictive Maintenance API is running.",
        "health": "/health",
        "predict": "/predictive-maintenance",
        "chat": "/chat-assistant",
    }


@app.post("/chat-assistant", response_model=ChatResponse)
def chat_assistant(payload: ChatRequest) -> ChatResponse:
    answer = ""
    confidence = 0.0
    source = "fallback"

    try:
        answer = _call_chat_api(payload.query)
        confidence = 0.9
        source = "ollama"
    except Exception:
        # Keep local deterministic fallback so support chat still works when the
        # Ollama service or backend model stack is unavailable.
        answer, confidence = _find_best_chat_answer(payload.query)
        source = "fallback"

    return ChatResponse(
        answer=answer,
        confidence=confidence,
        suggested_questions=_suggested_questions(),
        source=source,
    )


@app.post("/predictive-maintenance", response_model=PredictiveResponse)
def predict(payload: SensorInput) -> PredictiveResponse:
    if MODEL_REGISTRY is None:
        raise HTTPException(status_code=503, detail="Models not loaded")

    features = _build_feature_vector(payload, MODEL_REGISTRY)
    operational_proxy = _operational_health_proxy(payload)

    try:
        fault_prediction, fault_confidence = _predict_fault(features, MODEL_REGISTRY)
        rul = _predict_rul(features, MODEL_REGISTRY)
        anomaly = _predict_anomaly(features, MODEL_REGISTRY)
        future_temp, forecast_series = _predict_forecast(payload, MODEL_REGISTRY)

        # If the raw sensor state is clearly healthy, avoid over-escalating the
        # model labels. This keeps dashboard outputs aligned with the hardware state.
        if operational_proxy >= 0.78 and rul > 300:
            if fault_prediction in {
                "DUST_FAULT",
                "OVERHEAT",
                "OVERLOAD",
                "VIBRATION_FAULT",
                "BEARING_WEAR",
            }:
                fault_prediction = "NORMAL"
                fault_confidence = min(fault_confidence, 40.0)
            anomaly = "NORMAL"

        health_score, risk_level = _calculate_health_and_risk(
            fault_prediction,
            fault_confidence,
            rul,
            anomaly,
        )
        recommendation = _derive_recommendation(
            fault_prediction,
            anomaly,
            risk_level,
        )

        return PredictiveResponse(
            fault_prediction=fault_prediction,
            fault_confidence=fault_confidence,
            remaining_useful_life=rul,
            anomaly_status=anomaly,
            future_forecast_temp=future_temp,
            maintenance_recommendation=recommendation,
            health_score=health_score,
            risk_level=risk_level,
            forecast_series=[round(x, 3) for x in forecast_series],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Inference failed: {exc}") from exc


if __name__ == "__main__":
    import uvicorn

    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=False)
