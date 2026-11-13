/// Notifications of the signed-in user (Fiori shell bar).
module neko.eam.application.dtos.notificationdtos;

/// One notification: an alert (due / overdue item computed from the data) or an activity of another user.
struct NotificationDto {
	string id;
	string category;     /// "alert" | "activity"
	/// alert: ProductEndOfLife, ProductEndOfSupport, ..., DocumentReviewOverdue, ProtectionReviewOverdue,
	///        WorkPackageDelayed, ControlOverdue, RiskDue, KpiOffTrack
	/// activity: Updated | Deleted | Commented
	string kind;
	string priority;     /// High | Medium | Low
	string elementSet;
	string elementId;
	string elementName;
	string date;         /// alert: due date (YYYY-MM-DD, may be empty); activity: ISO timestamp
	string actor;        /// activity: user who made the change
	string text;         /// alert: English message; activity: comment excerpt
	string[] fields;     /// activity Updated: changed fields
	bool unread;
}

struct NotificationListDto {
	size_t unread;
	NotificationDto[] items;   /// alerts first (by priority), then activities (newest first)
}
