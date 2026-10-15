import UIKit
import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main class AppDelegate:UIResponder,UIApplicationDelegate,UNUserNotificationCenterDelegate,MessagingDelegate {
 let store=AdminStore()
 private var lastEvent:String?
 func application(_ application:UIApplication,didFinishLaunchingWithOptions options:[UIApplication.LaunchOptionsKey:Any]?) -> Bool {
  FirebaseApp.configure();Messaging.messaging().delegate=self;UNUserNotificationCenter.current().delegate=self
  UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.badge,.sound]){_,_ in DispatchQueue.main.async{application.registerForRemoteNotifications()}}
  return true
 }
 func application(_ application:UIApplication,configurationForConnecting session:UISceneSession,options:UIScene.ConnectionOptions)->UISceneConfiguration{let c=UISceneConfiguration(name:"Prism Admin",sessionRole:session.role);c.sceneClass=UIWindowScene.self;c.delegateClass=AdminSceneDelegate.self;return c}
 func application(_ application:UIApplication,didRegisterForRemoteNotificationsWithDeviceToken token:Data){Messaging.messaging().apnsToken=token}
 func messaging(_ messaging:Messaging,didReceiveRegistrationToken token:String?){guard let token=token else{return};UserDefaults.standard.set(token,forKey:"adminFCMToken");Task{@MainActor in await store.syncPush()}}
 func open(_ response:UNNotificationResponse){let data=response.notification.request.content.userInfo;guard let section=data["section"] as? String else{return};let event=data["event"] as? String ?? response.notification.request.identifier;guard event != lastEvent else{return};lastEvent=event;store.open(section)}
 func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completion:@escaping(UNNotificationPresentationOptions)->Void){Task{@MainActor in await store.refreshCounts()};completion([.banner,.sound,.badge])}
 func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completion:@escaping()->Void){DispatchQueue.main.async{self.open(response);completion()}}
}
final class AdminSceneDelegate:UIResponder,UIWindowSceneDelegate {
 var window:UIWindow?
 func scene(_ scene:UIScene,willConnectTo session:UISceneSession,options:UIScene.ConnectionOptions){guard let scene=scene as? UIWindowScene,let app=UIApplication.shared.delegate as? AppDelegate else{return};let window=UIWindow(windowScene:scene);window.rootViewController=UIHostingController(rootView:NativeAdminRoot(store:app.store));self.window=window;window.makeKeyAndVisible();if let response=options.notificationResponse{app.open(response)}}
 func sceneDidBecomeActive(_ scene:UIScene){guard let app=UIApplication.shared.delegate as? AppDelegate else{return};app.store.resume();Task{await app.store.refreshCounts();await app.store.syncPush()}}
 func sceneWillResignActive(_ scene:UIScene){(UIApplication.shared.delegate as? AppDelegate)?.store.pause()}
 func sceneDidDisconnect(_ scene:UIScene){(UIApplication.shared.delegate as? AppDelegate)?.store.pause();window=nil}
}
