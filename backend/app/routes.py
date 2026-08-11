from flask import Blueprint, jsonify

api = Blueprint("api", __name__)


@api.get("/health")
def health():
    return jsonify({"ok": True, "service": "controller"})


@api.get("/")
def root():
    return jsonify({"ok": True, "service": "controller", "role": "guest-entry"})
