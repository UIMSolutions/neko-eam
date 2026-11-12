sap.ui.define([
	"sap/base/strings/formatMessage"
], function (formatMessage) {
	"use strict";

	return {
		/** i18n pattern with placeholder, e.g. "{0} mission critical" */
		message: function (sPattern, vArg) {
			return sPattern ? formatMessage(sPattern, [vArg === undefined ? "" : vArg]) : "";
		},

		/** Lifecycle status -> sap.ui.core.ValueState */
		statusState: function (sStatus) {
			switch (sStatus) {
				case "Active": return "Success";
				case "Plan":
				case "Build": return "Information";
				case "PhaseOut": return "Warning";
				case "Retired": return "Error";
				default: return "None";
			}
		},

		/** Gartner TIME category -> ValueState */
		timeState: function (sTime) {
			switch (sTime) {
				case "Invest": return "Success";
				case "Tolerate": return "Information";
				case "Migrate": return "Warning";
				case "Eliminate": return "Error";
				default: return "None";
			}
		},

		criticalityState: function (sCriticality) {
			switch (sCriticality) {
				case "MissionCritical": return "Error";
				case "High": return "Warning";
				case "Medium": return "Information";
				default: return "None";
			}
		},

		projectState: function (sStatus) {
			switch (sStatus) {
				case "Completed": return "Success";
				case "InProgress": return "Information";
				case "Approved": return "Warning";
				case "Cancelled": return "Error";
				default: return "None";
			}
		},

		/** Business value / technical fit 1..5 -> RatingIndicator value. */
		score: function (iValue) {
			return Number(iValue) || 0;
		},

		coverageText: function (bGap, bRedundant) {
			if (bGap) { return "Gap"; }
			return bRedundant ? "Redundant" : "Covered";
		},

		coverageState: function (bGap, bRedundant) {
			if (bGap) { return "Error"; }
			return bRedundant ? "Warning" : "Success";
		},

		/** Array of ids -> comma separated text. */
		list: function (aValues) {
			return Array.isArray(aValues) ? aValues.join(", ") : "";
		},

		count: function (aValues) {
			return Array.isArray(aValues) ? aValues.length : 0;
		},

		/** Amount in millions with one decimal, e.g. 1435000 -> "1.4" (for NumericContent, scale "M") */
		millionAmount: function (fValue) {
			return ((Number(fValue) || 0) / 1000000).toFixed(1);
		},

		/** Generic value -> ValueState for enumeration values (lifecycle, approval, object state, risk ...). */
		valueState: function (sValue) {
			switch (sValue) {
				case "Active": case "Released": case "Approved": case "Invest": case "Completed": case "Low": case "Normal":
					return "Success";
				case "Plan": case "Build": case "Draft": case "Requested": case "InReview": case "Tolerate": case "InProgress": case "Medium":
					return "Information";
				case "PhaseOut": case "Deprecated": case "ApprovedWithConditions": case "Inactive": case "Migrate": case "High":
				case "VeryHigh": case "Archived":
					return "Warning";
				case "Retired": case "Withdrawn": case "Rejected": case "Eliminate": case "Critical": case "MissionCritical": case "Cancelled":
					return "Error";
				default: return "None";
			}
		},

		/** Severity of a product alert -> ValueState. */
		severityState: function (sSeverity) {
			switch (sSeverity) {
				case "Critical": return "Error";
				case "High": return "Warning";
				case "Medium": return "Information";
				default: return "None";
			}
		},

		/** Severity -> list item highlight. */
		severityHighlight: function (sSeverity) {
			switch (sSeverity) {
				case "Critical": return "Error";
				case "High": return "Warning";
				case "Medium": return "Information";
				default: return "None";
			}
		},

		/** ISO date (YYYY-MM-DD) -> medium local date. */
		date: function (sIso) {
			if (!sIso) { return "–"; }
			var d = new Date(sIso + "T00:00:00");
			return isNaN(d.getTime()) ? sIso : d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
		},

		/** Text with a dash for empty values (display mode). */
		text: function (vValue) {
			return vValue === undefined || vValue === null || vValue === "" ? "–" : String(vValue);
		},

		yesNo: function (bValue) {
			return bValue ? "Yes" : "No";
		},

		/** Reference id -> name (via lookup map), falls back to the id. */
		refName: function (sId, mNames) {
			if (!sId) { return "–"; }
			return (mNames && mNames[sId]) || sId;
		},

		/** Collection of ids -> comma separated names. */
		refNames: function (aIds, mNames) {
			if (!Array.isArray(aIds)) { return ""; }
			return aIds.map(function (sId) { return (mNames && mNames[sId]) || sId; }).join(", ");
		},

		/** Count of an entity set from the portfolio report. */
		setCount: function (mCounts, sSet) {
			return mCounts && mCounts[sSet] !== undefined ? String(mCounts[sSet]) : "";
		},

		/** ISO timestamp -> local date/time text. */
		timestamp: function (sIso) {
			if (!sIso) { return ""; }
			var d = new Date(sIso);
			return isNaN(d.getTime()) ? sIso : d.toLocaleString();
		},

		/** Large amounts in thousands, e.g. 1435000 -> "1,435k" */
		kiloAmount: function (fValue) {
			var f = Number(fValue) || 0;
			return Math.round(f / 1000).toLocaleString("en-US") + "k";
		}
	};
});
