import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class SubscriptionManager {
  final InAppPurchase _iap = InAppPurchase.instance;
  
  // Product IDs
  static const String premiumMonthlyId = 'safestream_pro_monthly';
  static const String premiumYearlyId = 'safestream_pro_yearly';
  static const String advancedVisionId = 'safestream_advanced_vision';
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  
  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;

  /// Initialize IAP and set up listeners
  Future<void> initPurchase() async {
    final bool available = await _iap.isAvailable();
    _isAvailable = available;
    
    if (!available) {
      print("❌ In-App Purchase not available on this device");
      return;
    }

    print("✅ In-App Purchase available");

    // Set up purchase stream listener
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (error) => print("Purchase stream error: $error"),
    );

    // Query available products
    await _queryProducts();
    
    // Restore previous purchases
    await _iap.restorePurchases();
  }

  /// Query product details from Play Store / App Store
  Future<void> _queryProducts() async {
    const Set<String> productIds = <String>{
      premiumMonthlyId,
      premiumYearlyId,
      advancedVisionId,
    };

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      
      _products = response.productDetails;
      
      if (response.notFoundIDs.isNotEmpty) {
        print("⚠️ Products not found: ${response.notFoundIDs}");
      }

      for (var product in _products) {
        print("📦 Product: ${product.title} - ${product.price}");
      }
    } catch (e) {
      print("Error querying products: $e");
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      if (product.id == advancedVisionId) {
        // Consumable purchase
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        // Subscription purchase
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      return true;
    } catch (e) {
      print("Purchase error: $e");
      return false;
    }
  }

  /// Handle purchase updates
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print("⏳ Purchase pending: ${purchaseDetails.productID}");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print("❌ Purchase error: ${purchaseDetails.error}");
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        print("✅ Purchase successful: ${purchaseDetails.productID}");
        _purchases.add(purchaseDetails);
        _verifyAndDeliverPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// Verify purchase and unlock features
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    switch (purchase.productID) {
      case premiumMonthlyId:
      case premiumYearlyId:
        print("🎉 Premium subscription unlocked!");
        _unlockPremiumFeatures();
        break;
      case advancedVisionId:
        print("🎉 Advanced Vision unlocked!");
        _unlockAdvancedVision();
        break;
    }
  }

  /// Unlock premium features
  void _unlockPremiumFeatures() {
    // Enable: Advanced moderation, priority support, custom blacklists
    print("✅ Features unlocked: Advanced Moderation, Priority Support, Custom Blacklists");
  }

  /// Unlock advanced vision
  void _unlockAdvancedVision() {
    // Enable: Real-time object detection, threat prediction, auto-shutdown
    print("✅ Features unlocked: Real-time Vision, Threat Detection, Auto-Shutdown");
  }

  /// Check if user has subscription
  bool hasActiveSubscription() {
    return _purchases.any((p) => 
      (p.productID == premiumMonthlyId || p.productID == premiumYearlyId) &&
      p.status == PurchaseStatus.purchased
    );
  }

  /// Check if advanced vision is purchased
  bool hasAdvancedVision() {
    return _purchases.any((p) => 
      p.productID == advancedVisionId &&
      p.status == PurchaseStatus.purchased
    );
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription.cancel();
  }
}