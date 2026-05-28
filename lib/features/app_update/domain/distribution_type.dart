/// How the running app was installed on the host.
///
/// [installer] copies are eligible for the in-app Level 2 auto-update flow;
/// [portable] (ZIP) copies only surface a "open release page" notification.
enum DistributionType { installer, portable }
