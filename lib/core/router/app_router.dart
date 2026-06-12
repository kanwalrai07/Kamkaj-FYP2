import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/root_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/client_login_screen.dart';
import '../../features/auth/presentation/screens/worker_login_screen.dart';
import '../../features/auth/presentation/screens/client_signup_screen.dart';
import '../../features/auth/presentation/screens/worker_signup_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/admin_login_screen.dart';
import '../../features/auth/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/worker/presentation/screens/worker_tracking_screen.dart';
import '../../features/client/presentation/screens/post_job_screen.dart';
import '../../features/client/presentation/screens/review_bids_screen.dart';
import '../../features/client/presentation/screens/live_tracking_screen.dart';
import '../../features/client/presentation/screens/client_profile_screen.dart';
import '../../features/worker/presentation/screens/job_details_screen.dart';
import '../../features/worker/presentation/screens/place_bid_screen.dart';
import '../../features/worker/presentation/screens/earnings_screen.dart';
import '../../features/worker/presentation/screens/worker_profile_screen.dart';
import '../../features/common/presentation/screens/chat_list_screen.dart';
import '../../features/common/presentation/screens/chat_detail_screen.dart';
import '../../features/common/presentation/screens/cnic_verification_screen.dart';
import '../../features/common/presentation/screens/job_history_screen.dart';
import '../../features/common/presentation/screens/rate_worker_screen.dart';
import '../../features/common/presentation/screens/notification_screen.dart';

import '../../features/client/presentation/screens/client_main_screen.dart';
import '../../features/worker/presentation/screens/worker_main_screen.dart';

class AppRouter {
  static const String splash = RouteNames.splash;
  static const String root = RouteNames.root;
  static const String roleSelection = RouteNames.roleSelection;
  static const String clientLogin = RouteNames.clientLogin;
  static const String workerLogin = RouteNames.workerLogin;
  static const String clientSignup = RouteNames.clientSignup;
  static const String workerSignup = RouteNames.workerSignup;
  static const String otpVerification = RouteNames.otpVerification;
  static const String resetPassword = RouteNames.resetPassword;
  static const String adminLogin = RouteNames.adminLogin;
  static const String adminDashboard = RouteNames.adminDashboard;
  static const String pendingApproval = RouteNames.pendingApproval;
  
  // Client Routes
  static const String clientHome = RouteNames.clientHome;
  static const String postJob = RouteNames.postJob;
  static const String reviewBids = RouteNames.reviewBids;
  static const String liveTracking = RouteNames.liveTracking;
  static const String clientProfile = RouteNames.clientProfile;
  
  // Worker Routes
  static const String workerDashboard = RouteNames.workerDashboard;
  static const String jobDetails = RouteNames.jobDetails;
  static const String placeBid = RouteNames.placeBid;
  static const String earnings = RouteNames.earnings;
  static const String workerProfile = RouteNames.workerProfile;
  static const String workerTracking = RouteNames.workerTracking;
  
  // Common Routes
  static const String chatList = RouteNames.chatList;
  static const String chatDetail = RouteNames.chatDetail;
  static const String cnicVerification = RouteNames.cnicVerification;
  static const String jobHistory = RouteNames.jobHistory;
  static const String rateWorker = RouteNames.rateWorker;
  static const String notifications = RouteNames.notifications;

  static final router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: root,
        builder: (context, state) => const RootScreen(),
      ),
      GoRoute(
        path: roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: clientLogin,
        builder: (context, state) => const ClientLoginScreen(),
      ),
      GoRoute(
        path: workerLogin,
        builder: (context, state) => const WorkerLoginScreen(),
      ),
      GoRoute(
        path: clientSignup,
        builder: (context, state) => const ClientSignupScreen(),
      ),
      GoRoute(
        path: workerSignup,
        builder: (context, state) => const WorkerSignupScreen(),
      ),
      GoRoute(
        path: otpVerification,
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return OTPVerificationScreen(
            email: extras['email'] as String?,
            phoneNumber: extras['phoneNumber'] as String?,
            verificationId: extras['verificationId'] as String?,
            userData: extras['userData'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: pendingApproval,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      
      // Client Routes
      GoRoute(
        path: clientHome,
        builder: (context, state) => const ClientMainScreen(),
      ),
      GoRoute(
        path: postJob,
        builder: (context, state) => const PostJobScreen(),
      ),
      GoRoute(
        path: reviewBids,
        builder: (context, state) {
          final jobId = state.extra as String;
          return ReviewBidsScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: liveTracking,
        builder: (context, state) {
          final jobId = state.extra as String;
          return LiveTrackingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: clientProfile,
        builder: (context, state) => const ClientProfileScreen(),
      ),

      // Worker Routes
      GoRoute(
        path: workerDashboard,
        builder: (context, state) => const WorkerMainScreen(),
      ),
      GoRoute(
        path: jobDetails,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return JobDetailsScreen(
            jobId: extra['jobId'] as String,
            jobData: extra['jobData'] as Map<String, dynamic>,
          );
        },
      ),
      GoRoute(
        path: placeBid,
        builder: (context, state) {
          final jobId = state.extra as String;
          return PlaceBidScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: earnings,
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: workerProfile,
        builder: (context, state) => const WorkerProfileScreen(),
      ),
      GoRoute(
        path: workerTracking,
        builder: (context, state) {
          final jobId = state.extra as String;
          return WorkerTrackingScreen(jobId: jobId);
        },
      ),

      // Common Routes
      GoRoute(
        path: chatList,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: chatDetail,
        builder: (context, state) {
          final jobId = state.extra as String;
          return ChatDetailScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: cnicVerification,
        builder: (context, state) => const CNICVerificationScreen(),
      ),
      GoRoute(
        path: jobHistory,
        builder: (context, state) => const JobHistoryScreen(),
      ),
      GoRoute(
        path: rateWorker,
        builder: (context, state) {
          final workerId = state.extra as String;
          return RateWorkerScreen(workerId: workerId);
        },
      ),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationScreen(),
      ),
    ],
  );
}
