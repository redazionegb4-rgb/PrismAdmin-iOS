import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
 var window: UIWindow?
 private var controller: PrismViewController?
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  FirebaseApp.configure()
  Messaging.messaging().delegate = self
  UNUserNotificationCenter.current().delegate = self
  let window = UIWindow(frame: UIScreen.main.bounds)
  let controller = PrismViewController(); self.controller = controller
  window.rootViewController = AdminNavigationController(rootViewController: controller)
  window.makeKeyAndVisible(); self.window = window
  UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { _,_ in
   DispatchQueue.main.async { application.registerForRemoteNotifications() }
  }
  if let data = options?[.remoteNotification] as? [AnyHashable:Any], let section = data["section"] as? String { controller.openPush(section) }
  return true
 }
 func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) { Messaging.messaging().apnsToken = token }
 func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
  guard let token = token else { return }
  UserDefaults.standard.set(token, forKey: "adminFCMToken")
  DispatchQueue.main.async { self.controller?.syncPush() }
 }
 func applicationDidBecomeActive(_ application: UIApplication) { controller?.startPushSync() }
 func applicationWillResignActive(_ application: UIApplication) { controller?.stopPushSync() }
 func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) { completion([.banner,.sound,.badge]) }
 func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completion: @escaping () -> Void) {
  if let section = response.notification.request.content.userInfo["section"] as? String { controller?.openPush(section) }
  completion()
 }
}
final class AdminNavigationController: UINavigationController {
 override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
