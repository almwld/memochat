#!/usr/bin/env python3
"""Static audit for MemoChat's canonical icon assets."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "icons"
EXPECTED = {
    "chat", "message", "send", "reply", "forward", "attachment", "image",
    "video", "audio", "file", "microphone", "camera", "phone_call",
    "video_call", "contacts", "notifications", "search", "settings",
    "profile", "more",
}
files = {path.stem: path for path in ASSETS.glob("*.svg")}
assert set(files) == EXPECTED, f"asset set mismatch: {set(files) ^ EXPECTED}"
for name, path in files.items():
    text = path.read_text(encoding="utf-8")
    root = ET.fromstring(text)
    assert root.attrib.get("viewBox") == "0 0 24 24", name
    assert not re.search(r"<(script|image|foreignObject)\\b", text), name
    assert root.attrib.get("stroke-width") == "1.8", name

registry = (ROOT / "lib" / "core" / "theme" / "app_icons.dart").read_text()
for name in EXPECTED:
    assert f"assets/icons/{name}.svg" in registry, f"missing registry entry: {name}"

pubspec = (ROOT / "pubspec.yaml").read_text()
assert "- assets/icons/" in pubspec
notification = ROOT / "android/app/src/main/res/drawable/memochat_notification.xml"
assert notification.exists()
ET.parse(notification)
print(f"audit passed: {len(files)} SVG masters, registry, pubspec, and Android vector")
