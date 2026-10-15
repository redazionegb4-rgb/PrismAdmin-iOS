import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
 private weak var controller: PrismViewController?
 private var pendingSection: String?
 private var lastOpenedEvent: String?
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  FirebaseApp.configure()
  Messaging.messaging().delegate = self
  UNUserNotificationCenter.current().delegate = self
  UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { _,_ in
   DispatchQueue.main.async { application.registerForRemoteNotifications() }
  }
  return true
 }
 func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
  let config = UISceneConfiguration(name: "Prism Admin", sessionRole: session.role)
  config.sceneClass = UIWindowScene.self
  config.delegateClass = AdminSceneDelegate.self
  return config
 }
 func attach(_ controller: PrismViewController) {
  self.controller = controller
  if let section = pendingSection { pendingSection = nil; controller.openPush(section) }
 }
 func detach(_ controller: PrismViewController) {
  if self.controller === controller { self.controller = nil }
 }
 func openNotification(_ response: UNNotificationResponse) {
  let data = response.notification.request.content.userInfo
  guard let section = data["section"] as? String, ["support","photos","reports"].contains(section) else { return }
  let event = data["event"] as? String ?? response.notification.request.identifier
  guard event != lastOpenedEvent else { return }
  lastOpenedEvent = event
  if let controller = controller { controller.openPush(section) } else { pendingSection = section }
 }
 func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) { Messaging.messaging().apnsToken = token }
 func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
  guard let token = token else { return }
  UserDefaults.standard.set(token, forKey: "adminFCMToken")
  DispatchQueue.main.async { self.controller?.syncPush() }
 }
 func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) { completion([.banner,.sound,.badge]) }
 func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completion: @escaping () -> Void) {
  DispatchQueue.main.async { self.openNotification(response); completion() }
 }
}

final class AdminSceneDelegate: UIResponder, UIWindowSceneDelegate {
 var window: UIWindow?
 private var controller: PrismViewController?
 func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
  guard let windowScene = scene as? UIWindowScene else { return }
  let controller = PrismViewController()
  self.controller = controller
  let window = UIWindow(windowScene: windowScene)
  window.rootViewController = AdminNavigationController(rootViewController: controller)
  self.window = window
  window.makeKeyAndVisible()
  if let delegate = UIApplication.shared.delegate as? AppDelegate {
   delegate.attach(controller)
   if let response = options.notificationResponse { delegate.openNotification(response) }
  }
 }
 func sceneDidBecomeActive(_ scene: UIScene) { controller?.startPushSync() }
 func sceneWillResignActive(_ scene: UIScene) { controller?.stopPushSync() }
 func sceneDidEnterBackground(_ scene: UIScene) { controller?.stopPushSync() }
 func sceneDidDisconnect(_ scene: UIScene) {
  if let controller = controller {
   controller.stopPushSync()
   (UIApplication.shared.delegate as? AppDelegate)?.detach(controller)
  }
  controller = nil; window = nil
 }
}
final class AdminNavigationController: UINavigationController {
 override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
