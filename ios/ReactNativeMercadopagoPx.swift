import UIKit
import Foundation
import MercadoPagoSDK

@objc(ReactNativeMercadopagoPx)
class ReactNativeMercadopagoPx: NSObject {
    private var navigationController: UINavigationController? = nil;
    
    private var resolver: RCTPromiseResolveBlock? = nil;
    private var rejecter: RCTPromiseRejectBlock? = nil;

    @objc(createPayment:resolver:rejecter:)
    func createPayment(options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        DispatchQueue.main.async {
            self.navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController;
                
            self.resolver = resolve;
            self.rejecter = reject;
                
            let publicKey = options[JsOptions.PUBLIC_KEY] as! String?;
            let preferenceId = options[JsOptions.PREFERENCE_ID] as! String?;

            if (publicKey == nil) {
                // TODO: extract error to custom error
                self.rejecter?(
                    JsErrorTypes.PUBLIC_KEY_REQUIRED,
                    "Public key is required for starting MP Checkout",
                    nil
                );
            }

            if (preferenceId == nil) {
                // TODO: extract error to custom error
                self.rejecter?(
                    JsErrorTypes.PREFERENCE_ID_REQUIRED,
                    "Preference ID is required for starting MP Checkout",
                    nil
                );
            }

            let builder = MercadoPagoCheckoutBuilder(publicKey: publicKey!, preferenceId: preferenceId!);

            // TODO: add support for language in Android side
            let language = options[JsOptions.LANGUAGE] as! String?;

            if (language != nil) {
                builder.setLanguage(language!);
            }

            let advancedOptions = options[JsOptions.ADVANCED_OPTIONS] as! NSDictionary?;

            if (advancedOptions != nil) {
                let config = PXAdvancedConfiguration();
                    
                let productId = advancedOptions![JsOptions.PRODUCT_ID] as! String?;

                if productId != nil {
                    config.setProductId(id: productId!);
                }
                    
                let bankDealsEnabled = advancedOptions?[JsOptions.BANK_DEALS_ENABLED] as! Bool?;
                let amountRowEnabled = advancedOptions?[JsOptions.AMOUNT_ROW_ENABLED] as! Bool?;

                config.bankDealsEnabled = bankDealsEnabled!;
                config.amountRowEnabled = amountRowEnabled!;
                
                builder.setAdvancedConfiguration(config: config);
            }

            // TODO: add support for tracking listener
            // TODO: add support for customizing fonts
            // TODO: add support for customizing colors

            let checkout = MercadoPagoCheckout(builder: builder);

            checkout.start(navigationController: self.navigationController!, lifeCycleProtocol: self);
        };
    }
    
    func setUpNavigationController() -> Void {
        self.navigationController?.setNavigationBarHidden(true, animated: true);
        self.navigationController?.popToRootViewController(animated: true);
    }
}

extension ReactNativeMercadopagoPx: PXLifeCycleProtocol {
    func finishCheckout() -> ((PXResult?) -> Void)? {
        return ({(_ result: PXResult?) in
            self.setUpNavigationController();
            
            if (result == nil) {
                self.rejecter?(
                    JsErrorTypes.PAYMENT_ERRORED,
                    "Something went wrong when retrieving Payment, please retry",
                    nil
                );
                
                self.rejecter = nil;
            }
            
            var payment: [String : Any?] = [:];
            
            if let pxPayment = (result as? PXPayment) {
                // Default Payment values
                payment[JsPaymentOptions.ID] = pxPayment.id;
                payment[JsPaymentOptions.STATUS] = pxPayment.status;
                payment[JsPaymentOptions.STATUS_DETAIL] = pxPayment.statusDetail;
                
                // Additional Payment values
                payment[JsPaymentOptions.PAYMENT_METHOD_ID] = pxPayment.paymentMethodId;
                payment[JsPaymentOptions.PAYMENT_TYPE_ID] = pxPayment.paymentTypeId;
                payment[JsPaymentOptions.ISSUER_ID] = pxPayment.issuerId;
                payment[JsPaymentOptions.INSTALLMENTS] = pxPayment.installments;
                payment[JsPaymentOptions.CAPTURED] = pxPayment.captured;
                payment[JsPaymentOptions.LIVE_MODE] = pxPayment.liveMode;
                payment[JsPaymentOptions.TRANSACTION_AMOUNT] = String(describing: "\(String(describing: pxPayment.transactionAmount))");
                payment[JsPaymentOptions.TRANSACTION_DETAILS] = pxPayment.transactionDetails;
            } else {
                // Default Payment values
                payment[JsPaymentOptions.ID] = Int(result?.getPaymentId() ?? "");
                payment[JsPaymentOptions.STATUS] = result?.getStatus();
                payment[JsPaymentOptions.STATUS_DETAIL] = result?.getStatusDetail();
            }
            
            self.resolver?(payment);
            self.resolver = nil;
        });
    }

    func cancelCheckout() -> (() -> Void)? {
        return {
            self.setUpNavigationController();
            self.rejecter?(
                JsErrorTypes.PAYMENT_CANCELLED,
                "Payment was cancelled by the user",
                nil
            );
            
            self.rejecter = nil;
        };
    }
}

// Options for JS Module
enum JsOptions {
    
    // Required Options
    static let PUBLIC_KEY = "publicKey";
    static let PREFERENCE_ID = "preferenceId";

    // Additional Options
    static let LANGUAGE = "language";
    static let PRODUCT_ID = "productId";
    static let ADVANCED_OPTIONS = "advancedOptions";
    static let BANK_DEALS_ENABLED = "bankDealsEnabled";
    static let AMOUNT_ROW_ENABLED = "amountRowEnabled";
}

// JS Exposed Error Types
enum JsErrorTypes {
    
    // Payment Error Types
    static let PAYMENT_ERRORED = "mp:payment_errored";
    static let PAYMENT_CANCELLED = "mp:payment_cancelled";
    
    // Required Options Error Types
    static let PUBLIC_KEY_REQUIRED = "mp:public_key_required";
    static let PREFERENCE_ID_REQUIRED = "mp:preference_id_required";
}

// JS Payment Options
enum JsPaymentOptions {
    
    // Default
    static let ID = "id";
    static let STATUS = "status";
    static let STATUS_DETAIL = "statusDetail";
    
    // Additional
    static let PAYMENT_METHOD_ID = "paymentMethodId";
    static let PAYMENT_TYPE_ID = "paymentTypeId";
    static let ISSUER_ID = "issuerId";
    static let INSTALLMENTS = "installments";
    static let CAPTURED = "captured";
    static let LIVE_MODE = "liveMode";
    static let TRANSACTION_AMOUNT = "transactionAmount";
    static let TRANSACTION_DETAILS = "transactionDetails";
}