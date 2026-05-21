# REST API Wrapper for gRPC Backend
from flask import Flask, jsonify, request
from flask_cors import CORS
import grpc
import json
import logging
from datetime import datetime

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModerationService:
    """Service to handle moderation"""
    def __init__(self, config_path='../assets/global_moderation_config.json'):
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = json.load(f)
        self.blacklists = self.config.get('blacklists', {})
        self.processed_messages = []
    
    def moderate_message(self, message):
        """Check and moderate a message"""
        clean_msg = message.lower()
        for lang, words in self.blacklists.items():
            for word in words:
                if word.lower() in clean_msg:
                    return {
                        "blocked": True,
                        "language": lang,
                        "message": message
                    }
        return {
            "blocked": False,
            "language": "clean",
            "message": message
        }
    
    def process_stream(self, live_chat_id, messages):
        """Process a stream of messages"""
        results = []
        for msg in messages:
            result = self.moderate_message(msg)
            result['live_chat_id'] = live_chat_id
            result['timestamp'] = datetime.now().isoformat()
            results.append(result)
            self.processed_messages.append(result)
        return results

# Initialize moderation service
moderator = ModerationService()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "SafeStream AI Backend"}), 200

@app.route('/api/moderate', methods=['POST'])
def moderate_message():
    """Moderate a single message"""
    data = request.json
    message = data.get('message', '')
    
    if not message:
        return jsonify({"error": "Message required"}), 400
    
    result = moderator.moderate_message(message)
    result['timestamp'] = datetime.now().isoformat()
    
    return jsonify(result), 200

@app.route('/api/stream/start', methods=['POST'])
def start_stream():
    """Start streaming and moderating messages"""
    data = request.json
    live_chat_id = data.get('live_chat_id')
    messages = data.get('messages', [])
    
    if not live_chat_id:
        return jsonify({"error": "live_chat_id required"}), 400
    
    results = moderator.process_stream(live_chat_id, messages)
    
    return jsonify({
        "live_chat_id": live_chat_id,
        "processed_count": len(results),
        "results": results
    }), 200

@app.route('/api/logs', methods=['GET'])
def get_logs():
    """Get moderation logs"""
    limit = request.args.get('limit', 100, type=int)
    return jsonify({
        "total": len(moderator.processed_messages),
        "logs": moderator.processed_messages[-limit:]
    }), 200

@app.route('/api/logs/clear', methods=['POST'])
def clear_logs():
    """Clear moderation logs"""
    count = len(moderator.processed_messages)
    moderator.processed_messages = []
    return jsonify({"message": f"Cleared {count} log entries"}), 200

@app.route('/api/config', methods=['GET'])
def get_config():
    """Get moderation config"""
    return jsonify({
        "languages": list(moderator.blacklists.keys()),
        "version": moderator.config.get('metadata', {}).get('version', '1.0.0')
    }), 200

if __name__ == '__main__':
    logger.info("Starting SafeStream AI REST API Server...")
    app.run(host='0.0.0.0', port=5000, debug=True)