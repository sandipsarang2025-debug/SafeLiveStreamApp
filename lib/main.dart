import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'services/global_moderator.dart';
import 'services/iap_service.dart';

void main() => runApp(SafeStreamApp());

class SafeStreamApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.red),
      home: LoginScreen(),
    );
  }
}

// --- AUTHENTICATION SCREEN ---
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 80, color: Colors.redAccent),
              SizedBox(height: 20),
              Text("SafeStream AI", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Text("Global Live Moderation", style: TextStyle(color: Colors.grey)),
              SizedBox(height: 50),
              _socialButton("Continue with Google", Icons.login, Colors.white, Colors.black, () {}),
              SizedBox(height: 12),
              _socialButton("Continue with Facebook", Icons.facebook, Colors.blueAccent, Colors.white, () {}),
              SizedBox(height: 12),
              _socialButton("Continue with X", Icons.close, Colors.black, Colors.white, () {}),
              SizedBox(height: 30),
              TextButton(
                child: Text("Enter Dashboard (Demo Mode)"),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard())),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String text, IconData icon, Color bg, Color txt, VoidCallback tap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: txt, padding: EdgeInsets.all(16)),
        icon: Icon(icon),
        label: Text(text),
        onPressed: tap,
      ),
    );
  }
}

// --- ENCRYPTED MODERATION LOG (2026 IT RULES COMPLIANCE) ---
class ModerationLogger {
  List<Map<String, dynamic>> encryptedLogs = [];
  
  // Simple Base64 encryption for demo (in production use proper encryption like AES)
  String _encryptMessage(String message) {
    return base64Encode(utf8.encode(message));
  }
  
  String _decryptMessage(String encrypted) {
    return utf8.decode(base64Decode(encrypted));
  }
  
  void logAction(String userId, String message, String violation) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      "time": timestamp,
      "user_id": userId,
      "content": _encryptMessage(message),
      "violation": violation,
      "action": "DELETED_WITHIN_120_SECONDS",
      "compliance_tag": "2026_IT_RULES",
      "encrypted": true
    };
    
    encryptedLogs.add(logEntry);
    print("🔐 LEGAL LOG CREATED (ENCRYPTED): ${logEntry['time']} | User: ${logEntry['user_id']} | Violation: ${logEntry['violation']}");
  }
  
  Map<String, dynamic> getDecryptedLog(int index) {
    if (index < 0 || index >= encryptedLogs.length) return {};
    
    final log = encryptedLogs[index];
    return {
      "time": log["time"],
      "user_id": log["user_id"],
      "content": _decryptMessage(log["content"]),
      "violation": log["violation"],
      "action": log["action"],
      "compliance_tag": log["compliance_tag"]
    };
  }
  
  List<Map<String, dynamic>> getAllDecryptedLogs() {
    return encryptedLogs.map((log) {
      return {
        "time": log["time"],
        "user_id": log["user_id"],
        "content": _decryptMessage(log["content"]),
        "violation": log["violation"],
        "action": log["action"]
      };
    }).toList();
  }
  
  int getLogsCount() => encryptedLogs.length;
}

// --- MODERATION DASHBOARD ---
class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? config;
  List<Map<String, String>> logs = [];
  ModerationLogger complianceLogger = ModerationLogger();
  bool isLoading = true;
  String currentUserId = "user_${DateTime.now().millisecondsSinceEpoch}";
  
  // Connect your uploaded tracking services
  late GlobalLanguageShield globalShield;
  late SubscriptionManager subscriptionManager;
  
  // Replace with your running Flask backend IP (rest_api.py)
  final String backendUrl = "http://YOUR_BACKEND_SERVER_IP:5000/api/moderate";

  @override
  void initState() {
    super.initState();
    _initializeModules();
  }

  Future<void> _initializeModules() async {
    // 1. Load the core dictionary configuration asset
    final String response = await rootBundle.loadString('assets/global_moderation_config.json');
    config = json.decode(response);

    // 2. Feed the configuration down to your Global Language Shield
    globalShield = GlobalLanguageShield(textBlacklist: config);

    // 3. Start your In-App Purchases tracking system
    subscriptionManager = SubscriptionManager();
    await subscriptionManager.initPurchase();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _processMessage(String input) async {
    if (input.isEmpty) return;

    // $1.00 USD Premium Guard validation rule
    bool isPremium = subscriptionManager.hasActiveSubscription();
    if (!isPremium && logs.length >= 15) {
      _showSubscriptionPrompt();
      return;
    }

    String detectedLanguage = "unknown";
    bool isBlocked = false;
    String reason = "Clean";

    try {
      // Phase A: Use your local ML engine for language identification
      detectedLanguage = await globalShield.getLanguage(input);
      isBlocked = await globalShield.isToxic(input, detectedLanguage);
      
      if (isBlocked) {
        reason = "Local Flagged (${detectedLanguage.toUpperCase()})";
      } else {
        // Phase B: Hybrid Fallback to your cloud server (rest_api.py)
        final serverResponse = await http.post(
          Uri.parse(backendUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"message": input}),
        ).timeout(Duration(seconds: 4));

        if (serverResponse.statusCode == 200) {
          final serverData = jsonDecode(serverResponse.body);
          if (serverData['blocked'] == true) {
            isBlocked = true;
            detectedLanguage = serverData['language'];
            reason = "Cloud Core Flagged";
          }
        }
      }
    } catch (e) {
      print("System routing error: $e");
    }

    // Save logs to your encrypted compliance layout
    if (isBlocked) {
      complianceLogger.logAction(currentUserId, input, reason);
    }

    setState(() {
      logs.insert(0, {
        "text": input,
        "status": isBlocked ? "BLOCKED" : "ALLOWED",
        "reason": isBlocked ? "Reason: $reason" : "Clean",
        "compliance_logged": isBlocked ? "✓" : "N/A"
      });
    });
  }

  void _showSubscriptionPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("🌟 Activate SafeStream Premium"),
        content: Text("You have reached the free monitoring limit. Unlock cross-platform visual AI and unlimited global language text parsing filters for just \$1.00 a month."),
        actions: [
          TextButton(child: Text("Later"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text("Subscribe Now"),
            onPressed: () {
              Navigator.pop(context);
              final product = subscriptionManager.getProduct(SubscriptionManager.premiumMonthlyId);
              if (product != null) subscriptionManager.purchaseProduct(product);
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Live Stream Guard"),
        actions: [
          IconButton(
            icon: Icon(Icons.description),
            onPressed: () => _showComplianceLogs(),
            tooltip: "View Encrypted Logs"
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => Navigator.pop(context)
          )
        ]
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              _buildTestInput(),
              _buildStatsBar(),
              Expanded(child: _buildLogList()),
            ],
          ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text("Total Messages", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text("${logs.length}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))
            ],
          ),
          Column(
            children: [
              Text("Blocked", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text("${logs.where((l) => l['status'] == 'BLOCKED').length}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))
            ],
          ),
          Column(
            children: [
              Text("Encrypted Logs", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text("${complianceLogger.getLogsCount()}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestInput() {
    TextEditingController controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: "Simulate live chat message...",
          suffixIcon: IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _processMessage(controller.text);
                controller.clear();
              }
            },
          ),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (val) {
          _processMessage(val);
          controller.clear();
        },
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, i) {
        bool blocked = logs[i]['status'] == "BLOCKED";
        return ListTile(
          leading: Icon(blocked ? Icons.block : Icons.check_circle, color: blocked ? Colors.red : Colors.green),
          title: Text(logs[i]['text']!),
          subtitle: Text(logs[i]['reason']!),
          trailing: blocked 
            ? Chip(label: Text("DELETED", style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.red)
            : null,
        );
      },
    );
  }

  void _showComplianceLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("🔐 Encrypted Compliance Logs (2026 IT Rules)"),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: complianceLogger.getLogsCount(),
            itemBuilder: (context, i) {
              final log = complianceLogger.getDecryptedLog(i);
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Time: ${log['time']}", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("User: ${log['user_id']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("Content: ${log['content']}", style: TextStyle(fontSize: 11)),
                      Text("Violation: ${log['violation']}", style: TextStyle(fontSize: 11, color: Colors.red)),
                      Text("Action: ${log['action']}", style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    globalShield.dispose();
    subscriptionManager.dispose();
    super.dispose();
  }
}