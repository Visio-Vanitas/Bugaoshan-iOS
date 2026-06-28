import Flutter
import CoreLocation
import EventKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate,
  FlutterImplicitEngineDelegate {
  private let channelName = "bugaoshan/update"
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBugaoshanMethodChannel(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func registerBugaoshanMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "listWritableCalendars":
        self?.listWritableCalendars(result: result)
      case "importIcsToCalendar":
        guard
          let arguments = call.arguments as? [String: Any],
          let events = arguments["events"] as? [[String: Any]],
          !events.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Events are empty",
            details: nil
          ))
          return
        }
        self?.importEventsToCalendar(
          events: events,
          calendarIdentifier: arguments["calendarIdentifier"] as? String,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func listWritableCalendars(result: @escaping FlutterResult) {
    // Listing the user's calendars is a read operation. On iOS 17+ that means
    // full calendar access; write-only access can save events but cannot power
    // a user-facing target-calendar picker.
    requestCalendarFullAccess { [weak self] granted, error in
      guard let self else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "APP_DELEGATE_RELEASED",
            message: "Unable to list calendars",
            details: nil
          ))
        }
        return
      }

      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        guard granted else {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_DENIED",
            message: "Calendar full access denied",
            details: nil
          ))
          return
        }

        let defaultIdentifier = self.eventStore
          .defaultCalendarForNewEvents?
          .calendarIdentifier
        let calendars = self.eventStore
          .calendars(for: .event)
          .filter { $0.allowsContentModifications }
          .map { calendar in
            [
              "id": calendar.calendarIdentifier,
              "title": calendar.title,
              "sourceTitle": calendar.source.title,
              "isDefault": calendar.calendarIdentifier == defaultIdentifier,
            ] as [String: Any]
          }
        result(calendars)
      }
    }
  }

  private func importEventsToCalendar(
    events: [[String: Any]],
    calendarIdentifier: String?,
    result: @escaping FlutterResult
  ) {
    // iOS/iPadOS do not provide a public API that silently imports a local
    // .ics file into Calendar. Writing the exported lessons through EventKit
    // gives iPad users a real one-tap import path instead of a file preview.
    requestCalendarAccess(
      needsCalendarList: calendarIdentifier != nil
    ) { [weak self] granted, error in
      guard let self else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "APP_DELEGATE_RELEASED",
            message: "Unable to import calendar events",
            details: nil
          ))
        }
        return
      }
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        guard granted else {
          result(FlutterError(
            code: "CALENDAR_PERMISSION_DENIED",
            message: "Calendar write access denied",
            details: nil
          ))
          return
        }
        self.saveEvents(
          events,
          calendarIdentifier: calendarIdentifier,
          result: result
        )
      }
    }
  }

  private func requestCalendarAccess(
    needsCalendarList: Bool,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if needsCalendarList {
      requestCalendarFullAccess(completion: completion)
    } else {
      requestCalendarWriteAccess(completion: completion)
    }
  }

  private func requestCalendarWriteAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestWriteOnlyAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func requestCalendarFullAccess(
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func saveEvents(
    _ payloads: [[String: Any]],
    calendarIdentifier: String?,
    result: @escaping FlutterResult
  ) {
    guard let targetCalendar = targetCalendar(identifier: calendarIdentifier) else {
      result(FlutterError(
        code: "NO_WRITABLE_CALENDAR",
        message: "No writable calendar is available",
        details: calendarIdentifier
      ))
      return
    }

    do {
      for (index, payload) in payloads.enumerated() {
        guard let event = makeEvent(
          from: payload,
          targetCalendar: targetCalendar
        ) else {
          result(FlutterError(
            code: "INVALID_EVENT",
            message: "Invalid calendar event payload",
            details: index
          ))
          return
        }
        try eventStore.save(event, span: .thisEvent, commit: false)
      }
      try eventStore.commit()
      result("imported")
    } catch {
      result(FlutterError(
        code: "CALENDAR_SAVE_FAILED",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func targetCalendar(identifier: String?) -> EKCalendar? {
    guard let identifier, !identifier.isEmpty else {
      return eventStore.defaultCalendarForNewEvents
    }
    guard
      let calendar = eventStore.calendar(withIdentifier: identifier),
      calendar.allowsContentModifications
    else {
      return nil
    }
    return calendar
  }

  private func makeEvent(
    from payload: [String: Any],
    targetCalendar: EKCalendar
  ) -> EKEvent? {
    guard
      let title = payload["title"] as? String,
      let startComponents = payload["start"] as? [String: Any],
      let endComponents = payload["end"] as? [String: Any]
    else {
      return nil
    }

    let timeZoneIdentifier = payload["timeZone"] as? String ?? "Asia/Shanghai"
    let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    guard
      let startDate = date(from: startComponents, timeZone: timeZone),
      let endDate = date(from: endComponents, timeZone: timeZone)
    else {
      return nil
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.location = payload["location"] as? String
    event.notes = payload["notes"] as? String
    event.startDate = startDate
    event.endDate = endDate
    event.timeZone = timeZone
    event.calendar = targetCalendar
    event.structuredLocation = structuredLocation(from: payload)
    return event
  }

  private func structuredLocation(
    from payload: [String: Any]
  ) -> EKStructuredLocation? {
    guard
      let locationPayload = payload["structuredLocation"] as? [String: Any],
      let title = locationPayload["title"] as? String,
      let latitude = doubleValue(locationPayload["latitude"]),
      let longitude = doubleValue(locationPayload["longitude"])
    else {
      return nil
    }

    let structuredLocation = EKStructuredLocation(title: title)
    structuredLocation.geoLocation = CLLocation(
      latitude: latitude,
      longitude: longitude
    )
    if let radius = doubleValue(locationPayload["radius"]) {
      structuredLocation.radius = radius
    }
    return structuredLocation
  }

  private func date(
    from payload: [String: Any],
    timeZone: TimeZone
  ) -> Date? {
    guard
      let year = intValue(payload["year"]),
      let month = intValue(payload["month"]),
      let day = intValue(payload["day"]),
      let hour = intValue(payload["hour"]),
      let minute = intValue(payload["minute"])
    else {
      return nil
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
      timeZone: timeZone,
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute
    ))
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }

  private func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double {
      return value
    }
    if let value = value as? NSNumber {
      return value.doubleValue
    }
    return nil
  }
}
