from __future__ import annotations

import os
import pickle
import re
import json
import logging
from itertools import product
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
    lstm_forecast: list[float] = []


class ChatRequest(BaseModel):
    query: str = Field(..., min_length=2, description="User chat query")


class ChatResponse(BaseModel):
    answer: str
    confidence: float
    suggested_questions: list[str] = []
    source: str = "fallback"


class PredictiveCombinationRequest(BaseModel):
    temperature_values: list[float] = Field(default_factory=list)
    vibration_values: list[float] = Field(default_factory=list)
    current_values: list[float] = Field(default_factory=list)
    gas_values: list[float] = Field(default_factory=list)
    dust_values: list[float] = Field(default_factory=list)
    sound_values: list[float] = Field(default_factory=list)
    deviceId: str | None = None
    max_combinations: int = Field(1000, ge=1, le=50000)


class PredictiveCombinationRow(BaseModel):
    input: SensorInput
    output: PredictiveResponse


class PredictiveCombinationResponse(BaseModel):
    total_combinations: int
    returned_combinations: int
    rows: list[PredictiveCombinationRow]


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


def _clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _predictive_rule_engine(sensor: SensorInput) -> PredictiveResponse:
    # Rules tuned for a single-phase 0.5 HP AC induction motor telemetry profile.
    temp_warn, temp_fault, temp_critical = 70.0, 80.0, 95.0
    current_warn, current_fault, current_critical = 4.2, 5.0, 6.2
    vib_warn, vib_fault, vib_critical = 1.8, 2.8, 4.0
    sound_warn, sound_fault, sound_critical = 62.0, 72.0, 82.0
    dust_warn, dust_fault, dust_critical = 180.0, 280.0, 380.0
    gas_warn, gas_fault, gas_critical = 250.0, 450.0, 700.0

    temp_risk = _clamp((sensor.temperature - temp_warn) / (temp_critical - temp_warn), 0.0, 1.0)
    current_risk = _clamp((sensor.current - current_warn) / (current_critical - current_warn), 0.0, 1.0)
    vibration_risk = _clamp((sensor.vibration - vib_warn) / (vib_critical - vib_warn), 0.0, 1.0)
    dust_risk = _clamp((sensor.dust - dust_warn) / (dust_critical - dust_warn), 0.0, 1.0)
    gas_risk = _clamp((sensor.gas - gas_warn) / (gas_critical - gas_warn), 0.0, 1.0)
    env_risk = max(dust_risk, gas_risk)
    sound_risk = _clamp((sensor.sound - sound_warn) / (sound_critical - sound_warn), 0.0, 1.0)

    overheat_issue = sensor.temperature >= temp_fault
    dust_fault_issue = sensor.dust >= dust_fault or sensor.gas >= gas_fault
    overload_issue = sensor.current >= current_fault
    vibration_issue = sensor.vibration >= vib_fault
    bearing_issue = (
        (sensor.vibration >= vib_warn and sensor.sound >= sound_fault)
        or (sensor.vibration >= vib_fault and sensor.temperature >= temp_warn)
    )

    critical_limit_crossed = (
        sensor.temperature >= temp_critical
        or sensor.current >= current_critical
        or sensor.vibration >= vib_critical
        or sensor.sound >= sound_critical
        or sensor.dust >= dust_critical
        or sensor.gas >= gas_critical
    )
    severe_count = sum(
        [
            1 if overheat_issue else 0,
            1 if dust_fault_issue else 0,
            1 if overload_issue else 0,
            1 if vibration_issue else 0,
            1 if bearing_issue else 0,
        ]
    )
    failure_imminent = critical_limit_crossed or severe_count >= 2

    if failure_imminent:
        fault_prediction = "FAILURE_IMMINENT"
    elif bearing_issue:
        fault_prediction = "BEARING_WEAR"
    elif vibration_issue:
        fault_prediction = "VIBRATION_FAULT"
    elif overload_issue:
        fault_prediction = "OVERLOAD"
    elif overheat_issue:
        fault_prediction = "OVERHEAT"
    elif dust_fault_issue:
        fault_prediction = "DUST_FAULT"
    else:
        fault_prediction = "NORMAL"

    fault_severity = {
        "NORMAL": 0.00,
        "DUST_FAULT": 0.45,
        "OVERHEAT": 0.55,
        "OVERLOAD": 0.60,
        "VIBRATION_FAULT": 0.65,
        "BEARING_WEAR": 0.78,
        "FAILURE_IMMINENT": 1.00,
    }[fault_prediction]

    risk_score = 100.0 * (
        (0.28 * temp_risk)
        + (0.24 * current_risk)
        + (0.20 * vibration_risk)
        + (0.12 * env_risk)
        + (0.10 * sound_risk)
        + (0.06 * fault_severity)
    )
    if failure_imminent:
        risk_score = max(risk_score, 88.0)

    if risk_score < 25.0:
        risk_level = "LOW"
    elif risk_score < 50.0:
        risk_level = "MEDIUM"
    elif risk_score < 75.0:
        risk_level = "HIGH"
    else:
        risk_level = "CRITICAL"

    anomaly_status = "ANOMALY" if fault_prediction != "NORMAL" else "NORMAL"

    health_score = int(round(_clamp(100.0 - risk_score, 0.0, 100.0)))
    base_rul = 60.0 + (health_score * 14.0)
    if fault_prediction == "FAILURE_IMMINENT":
        base_rul = min(base_rul, 48.0)
    elif fault_prediction in {"BEARING_WEAR", "VIBRATION_FAULT", "OVERHEAT", "OVERLOAD"}:
        base_rul = min(base_rul, 420.0)
    elif fault_prediction == "DUST_FAULT":
        base_rul = min(base_rul, 720.0)
    remaining_useful_life = int(round(_clamp(base_rul, 8.0, 1500.0)))

    confidence_base = 56.0 + (risk_score * 0.34)
    if fault_prediction == "NORMAL":
        confidence_base = max(confidence_base, 62.0)
    fault_confidence = round(_clamp(confidence_base, 55.0, 98.0), 2)

    maintenance_recommendation = {
        "NORMAL": "No immediate action needed. Continue routine monitoring.",
        "OVERHEAT": "Inspect cooling path, fan, and ventilation. Reduce thermal load.",
        "DUST_FAULT": "Clean motor housing and filters. Improve enclosure dust control.",
        "OVERLOAD": "Reduce shaft load and check supply voltage/current balance.",
        "VIBRATION_FAULT": "Check alignment, coupling, and rotor balance.",
        "BEARING_WEAR": "Inspect bearings, lubrication, and replace if wear is confirmed.",
        "FAILURE_IMMINENT": "Immediate shutdown and maintenance intervention required.",
    }[fault_prediction]

    forecast_adjust = {
        "NORMAL": -0.2,
        "DUST_FAULT": 1.2,
        "OVERHEAT": 6.0,
        "OVERLOAD": 3.5,
        "VIBRATION_FAULT": 2.0,
        "BEARING_WEAR": 4.5,
        "FAILURE_IMMINENT": 9.0,
    }[fault_prediction]
    future_forecast_temp = round(_clamp(sensor.temperature + forecast_adjust, 0.0, 140.0), 3)

    forecast_series = [
        round(_clamp(future_forecast_temp - (index * 0.55), 18.0, 140.0), 3)
        for index in range(12)
    ]

    lstm_forecast = []
    start = _clamp(float(remaining_useful_life), 0.0, 100000.0)
    decay = 0.0 if start <= 0 else _clamp(start / 14.0, 1.0, 50.0)
    for index in range(12):
        lstm_forecast.append(round(_clamp(start - (decay * index), 0.0, 100000.0), 3))

    return PredictiveResponse(
        fault_prediction=fault_prediction,
        fault_confidence=round(fault_confidence, 2),
        remaining_useful_life=remaining_useful_life,
        anomaly_status=anomaly_status,
        future_forecast_temp=future_forecast_temp,
        maintenance_recommendation=maintenance_recommendation,
        health_score=health_score,
        risk_level=risk_level,
        forecast_series=forecast_series,
        lstm_forecast=lstm_forecast,
    )


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

    # Rolling means (same as current)
    temp_roll_mean_10 = sensor.temperature
    gas_roll_mean_10 = sensor.gas
    dust_roll_mean_10 = sensor.dust
    current_roll_mean_10 = sensor.current
    sound_roll_mean_10 = sensor.sound

    # 🔥 ADD SMALL DYNAMIC VARIATION
    temp_diff = sensor.temperature * 0.01
    gas_diff = sensor.gas * 0.01
    dust_diff = sensor.dust * 0.01
    current_diff = sensor.current * 0.01
    sound_diff = sensor.sound * 0.01

    temp_roll_std_10 = sensor.temperature * 0.02
    gas_roll_std_10 = sensor.gas * 0.02
    dust_roll_std_10 = sensor.dust * 0.02
    current_roll_std_10 = sensor.current * 0.02
    sound_roll_std_10 = sensor.sound * 0.02

    mpu_a_mag_roll_std_10 = mpu_a_mag * 0.02
    adxl_a_mag_roll_std_10 = adxl_a_mag * 0.02

    # Normalized values
    temp_norm = sensor.temperature / 100.0
    vib_norm = sensor.vibration / 10.0
    current_norm = sensor.current / 15.0
    gas_norm = sensor.gas / 1000.0
    dust_norm = sensor.dust / 500.0
    sound_norm = sensor.sound / 120.0

    health_proxy = max(
        0.0,
        1.0 - (
            0.3 * temp_norm +
            0.25 * vib_norm +
            0.2 * current_norm +
            0.15 * gas_norm +
            0.05 * dust_norm +
            0.05 * sound_norm
        ),
    )

    # 🔥 ADD VARIATION HERE ALSO
    rul_proxy = max(1.0, health_proxy * 2000.0 * (1 + sensor.vibration * 0.01))

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

        # 🔥 FIXED (dynamic instead of 0)
        "temp_diff": temp_diff,
        "gas_diff": gas_diff,
        "dust_diff": dust_diff,
        "current_diff": current_diff,
        "sound_diff": sound_diff,
        "mpu_a_mag_diff": mpu_a_mag * 0.01,
        "adxl_a_mag_diff": adxl_a_mag * 0.01,

        "temp_roll_mean_10": temp_roll_mean_10,
        "temp_roll_std_10": temp_roll_std_10,
        "gas_roll_mean_10": gas_roll_mean_10,
        "gas_roll_std_10": gas_roll_std_10,
        "dust_roll_mean_10": dust_roll_mean_10,
        "dust_roll_std_10": dust_roll_std_10,
        "current_roll_mean_10": current_roll_mean_10,
        "current_roll_std_10": current_roll_std_10,
        "sound_roll_mean_10": sound_roll_mean_10,
        "sound_roll_std_10": sound_roll_std_10,
        "mpu_a_mag_roll_mean_10": mpu_a_mag,
        "mpu_a_mag_roll_std_10": mpu_a_mag_roll_std_10,
        "adxl_a_mag_roll_mean_10": adxl_a_mag,
        "adxl_a_mag_roll_std_10": adxl_a_mag_roll_std_10,

        "rul_proxy_hours": rul_proxy,
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
        top = float(np.max(probs))
        sorted_probs = np.sort(probs)
        second = float(sorted_probs[-2]) if len(sorted_probs) > 1 else 0.0
        margin = max(0.0, top - second)
        entropy = float(-np.sum(probs * np.log(np.clip(probs, 1e-9, 1.0))))
        max_entropy = float(np.log(len(probs))) if len(probs) > 1 else 1.0
        entropy_term = 1.0 - (entropy / max(max_entropy, 1e-9))

        composite = (0.60 * margin) + (0.25 * top) + (0.15 * entropy_term)
        calibrated = 1.0 - float(np.exp(-3.0 * composite))
        confidence = float(np.clip(calibrated * 100.0, 20.0, 98.0))

    return str(decoded).upper(), round(confidence, 2)


def _predict_rul(features: np.ndarray, sensor: SensorInput, models: ModelRegistry) -> int:
    LOGGER.info("ENTERING _predict_rul")
    print("ENTERING _predict_rul", flush=True)
    model_features = _align_features_for_model(features, models.rul_model)
    raw_value = float(models.rul_model.predict(model_features)[0])
    LOGGER.info("RAW RUL VALUE: %s", raw_value)
    print(f"RAW RUL VALUE: {raw_value}", flush=True)

    # Normalize model output (0-1) to RUL horizon and apply smooth proportional degradation.
    if 0.0 <= raw_value <= 1.0:
        base_rul = raw_value * 1500.0
    else:
        base_rul = raw_value

    degradation_factor = (
        (sensor.temperature / 120.0) +
        (sensor.vibration / 10.0) +
        (sensor.current / 10.0)
    ) / 3.0

    adjusted_rul = base_rul * (1 - 0.5 * degradation_factor)
    final_rul = max(10, int(adjusted_rul))

    LOGGER.info(
        "Validation Log - raw_rul: %.4f, base_rul: %.4f, degradation_factor: %.4f, adjusted_rul: %.4f",
        raw_value,
        base_rul,
        degradation_factor,
        adjusted_rul,
    )
    LOGGER.info("EXITING _predict_rul")
    print("EXITING _predict_rul", flush=True)
    return final_rul


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
        return _normalize_temperature_forecast(series, sensor.temperature)

    # Fallback to sklearn-like predictor serialized as .pth.
    if hasattr(models.lstm_model, "predict"):
        out = models.lstm_model.predict(values.reshape(1, -1))
        arr = np.array(out).reshape(-1)
        series = [float(x) for x in arr[:12]]
        return _normalize_temperature_forecast(series, sensor.temperature)

    # Safe deterministic fallback if model format is unexpected.
    baseline = float(sensor.temperature)
    series = [baseline - (i * 0.4) for i in range(12)]
    return _normalize_temperature_forecast(series, baseline)


def _normalize_temperature_forecast(raw_series: list[float], current_temperature: float) -> tuple[float, list[float]]:
    if not raw_series:
        series = [max(18.0, round(current_temperature - (i * 0.5), 3)) for i in range(12)]
        return round(series[0], 3), series

    start = float(current_temperature)
    if raw_series[0] > start:
        raw_series = [start - (index * 0.6) for index in range(len(raw_series))]

    series: list[float] = []
    previous = start + 0.5
    for index, value in enumerate(raw_series):
        target = min(value, previous - 0.1)
        if index == 0:
            target = min(target, start - 0.2)
        target = max(18.0, target)
        series.append(round(target, 3))
        previous = target

    if series and series[-1] >= 20.0:
        drop = max(0.5, (series[0] - 18.0) / max(len(series) - 1, 1))
        series = [round(max(18.0, series[0] - (drop * i)), 3) for i in range(len(series))]

    return round(series[0], 3), series


def _build_rul_forecast_series(rul: int, sensor: SensorInput, steps: int = 12) -> list[float]:
    start = max(0.0, float(rul))
    # Use the current sensor load to decide how quickly the countdown drops.
    stress = (
        (sensor.temperature / 120.0)
        + (sensor.vibration / 10.0)
        + (sensor.current / 10.0)
        + (sensor.gas / 5000.0)
        + (sensor.dust / 4000.0)
        + (sensor.sound / 120.0)
    ) / 6.0
    decay = max(1.0, min(start / max(steps - 1, 1), 5.0 + (stress * 6.0)))

    series: list[float] = []
    for index in range(steps):
        value = max(0.0, start - (decay * index))
        series.append(round(value, 3))

    return series


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
        "DUST_FAULT": 5,
        "OVERHEAT": 15,
        "OVERLOAD": 20,
        "VIBRATION_FAULT": 20,
        "BEARING_WEAR": 25,
        "FAILURE_IMMINENT": 35,
    }.get(fault, 15)


def _calculate_health_and_risk(
    sensor: SensorInput,
    fault: str,
    fault_confidence: float,
    rul: int,
    anomaly: str,
) -> tuple[int, str]:
    severity = _fault_severity_weight(fault)

    # Continuous health score calculation.
    temp_penalty = (sensor.temperature / 120.0) * 25.0
    vib_penalty = (sensor.vibration / 10.0) * 20.0
    curr_penalty = (sensor.current / 10.0) * 20.0
    gas_penalty = (sensor.gas / 5000.0) * 12.0
    dust_penalty = (sensor.dust / 4000.0) * 8.0
    sound_penalty = (sensor.sound / 120.0) * 6.0
    anomaly_penalty = 15.0 if anomaly == "ANOMALY" else 0.0
    fault_penalty = severity * (fault_confidence / 100.0)

    health = 100.0 - (
        temp_penalty
        + vib_penalty
        + curr_penalty
        + gas_penalty
        + dust_penalty
        + sound_penalty
        + anomaly_penalty
        + fault_penalty
    )
    health_score = max(0, min(100, int(round(health))))

    # Continuous risk score with weighted impacts.
    rul_impact = max(0.0, (300.0 - float(rul)) / 300.0) * 30.0
    health_impact = (100.0 - float(health_score)) * 0.4
    anomaly_impact = 20.0 if anomaly == "ANOMALY" else 0.0
    fault_impact = float(severity)
    confidence_impact = fault_confidence * 0.1
    gas_impact = (sensor.gas / 5000.0) * 10.0
    dust_impact = (sensor.dust / 4000.0) * 8.0
    sound_impact = (sensor.sound / 120.0) * 6.0

    risk_score = (
        rul_impact
        + health_impact
        + anomaly_impact
        + fault_impact
        + confidence_impact
        + gas_impact
        + dust_impact
        + sound_impact
    )

    if risk_score < 30:
        risk = "LOW"
    elif risk_score < 60:
        risk = "MEDIUM"
    elif risk_score < 85:
        risk = "HIGH"
    else:
        risk = "CRITICAL"

    LOGGER.info(
        "Validation Log - health_score: %s, risk_score: %.4f, rul_impact: %.4f, health_impact: %.4f",
        health_score,
        risk_score,
        rul_impact,
        health_impact,
    )

    return health_score, risk


def load_models() -> ModelRegistry:
    fault_model = _load_pickle(MODEL_DIR / "motor_fault_gpu_model.pkl")
    rul_model = _load_pickle(MODEL_DIR / "rul_proxy_model.pkl")
    anomaly_model = _load_pickle(MODEL_DIR / "improved_anomaly_model.pkl")
    label_encoder = _load_pickle(MODEL_DIR / "label_encoder.pkl")
    lstm_model = _load_lstm_model(MODEL_DIR / "lstm_forecast_model.pth")

    # Force CPU inference for XGBoost models to avoid per-request device mismatch
    # fallback (GPU-trained model + CPU input), which can increase latency.
    for model in (fault_model, rul_model):
        if hasattr(model, "set_params"):
            try:
                model.set_params(device="cpu")
            except Exception:
                pass

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
    MODEL_REGISTRY = None
    LOGGER.info("Rule-based predictive backend initialized; ML model loading is disabled.")
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
    return {
        "status": "ok",
        "predictive_mode": "rule-based",
        "chat_api": "ollama-active" if ollama_ready else "fallback-mode",
        "chat_model": OLLAMA_MODEL,
        "chat_provider": "ollama",
    }


@app.get("/debug-models")
def debug_models() -> dict[str, Any]:
    """Diagnostic endpoint – reports rule-based inference status."""
    return {
        "model_dir": str(MODEL_DIR),
        "predictive_mode": "rule-based",
        "registry_loaded": False,
    }

@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "ReVolve Predictive Maintenance API is running.",
        "health": "/health",
        "predict": "/predictive-maintenance",
        "predict_combinations": "/predictive-maintenance/combinations",
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
    LOGGER.info("API RECEIVED REQUEST")
    print("API RECEIVED REQUEST", flush=True)

    try:
        return _predictive_rule_engine(payload)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Inference failed: {exc}") from exc
    finally:
        LOGGER.info("API FINISHED PROCESSING")
        print("API FINISHED PROCESSING", flush=True)


@app.post(
    "/predictive-maintenance/combinations",
    response_model=PredictiveCombinationResponse,
)
def predict_combinations(
    payload: PredictiveCombinationRequest,
) -> PredictiveCombinationResponse:
    temps = payload.temperature_values or [45.0]
    vibs = payload.vibration_values or [1.0]
    currents = payload.current_values or [2.5]
    gases = payload.gas_values or [150.0]
    dusts = payload.dust_values or [100.0]
    sounds = payload.sound_values or [50.0]

    total = (
        len(temps)
        * len(vibs)
        * len(currents)
        * len(gases)
        * len(dusts)
        * len(sounds)
    )

    if total > payload.max_combinations:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Requested {total} combinations exceeds max_combinations="
                f"{payload.max_combinations}."
            ),
        )

    rows: list[PredictiveCombinationRow] = []
    for temp, vib, current, gas, dust, sound in product(
        temps,
        vibs,
        currents,
        gases,
        dusts,
        sounds,
    ):
        sensor_input = SensorInput(
            temperature=float(temp),
            vibration=float(vib),
            current=float(current),
            gas=float(gas),
            dust=float(dust),
            sound=float(sound),
            deviceId=payload.deviceId,
        )
        prediction = _predictive_rule_engine(sensor_input)
        rows.append(PredictiveCombinationRow(input=sensor_input, output=prediction))

    return PredictiveCombinationResponse(
        total_combinations=total,
        returned_combinations=len(rows),
        rows=rows,
    )


if __name__ == "__main__":
    import uvicorn

    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run("main:app", host=host, port=port, reload=False)
