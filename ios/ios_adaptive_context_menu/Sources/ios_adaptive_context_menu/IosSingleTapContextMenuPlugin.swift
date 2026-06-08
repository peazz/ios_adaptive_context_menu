import Flutter
import UIKit

public final class IosSingleTapContextMenuPlugin: NSObject, FlutterPlugin {
  private let messenger: FlutterBinaryMessenger
  private weak var anchorButton: NoHighlightButton?
  private var anchorButtonInstanceId: String?

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ios_adaptive_context_menu/methods",
      binaryMessenger: registrar.messenger()
    )
    let plugin = IosSingleTapContextMenuPlugin(messenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showMenu":
      guard #available(iOS 14.0, *) else {
        result(nil)
        return
      }
      showMenu(from: call.arguments)
      result(nil)
    case "disposeInstance":
      disposeInstance(from: call.arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 14.0, *)
  private func showMenu(from args: Any?) {
    guard
      let dictionary = args as? [String: Any],
      let instanceId = dictionary["instanceId"] as? String,
      !instanceId.isEmpty
    else {
      return
    }

    let items = parseItems(from: dictionary)
    let groups = buildGroups(from: items)
    guard !groups.isEmpty else {
      return
    }

    guard
      let window = keyWindow(),
      let rootView = window.rootViewController?.view
    else {
      return
    }

    cleanupAnchorButton()

    let anchorRect = resolvedAnchorRect(from: dictionary, in: rootView)
    let button = NoHighlightButton(type: .system)
    button.frame = anchorRect
    button.backgroundColor = .clear
    button.showsTouchWhenHighlighted = false
    button.adjustsImageWhenHighlighted = false
    button.showsMenuAsPrimaryAction = true
    button.overrideUserInterfaceStyle = resolvedUserInterfaceStyleFromFlutterTheme(from: dictionary)
    
    if #available(iOS 16.0, *) {
      button.preferredMenuElementOrder = .fixed
    }

    if #available(iOS 15.0, *) {
      button.changesSelectionAsPrimaryAction = false
    }

    button.menu = UIMenu(
      title: "",
      children: groups.map { group in
        UIMenu(title: "", options: [.displayInline], children: group.map { item in
          makeElement(from: item, instanceId: instanceId)
        })
      }
    )

    rootView.addSubview(button)
    anchorButton = button
    anchorButtonInstanceId = instanceId

    DispatchQueue.main.async {
      self.presentMenu(for: button)
    }
  }

  @available(iOS 14.0, *)
  private func presentMenu(for button: UIButton) {
    if #available(iOS 17.4, *) {
      button.performPrimaryAction()
      return
    }

    
    
    button.sendActions(for: .touchDown)
  }

  private func resolvedAnchorRect(from args: [String: Any], in rootView: UIView) -> CGRect {
    let x = (args["x"] as? NSNumber)?.doubleValue ?? Double(rootView.bounds.midX)
    let y = (args["y"] as? NSNumber)?.doubleValue ?? Double(rootView.bounds.midY)
    let width = max((args["width"] as? NSNumber)?.doubleValue ?? 44, 1)
    let height = max((args["height"] as? NSNumber)?.doubleValue ?? 44, 1)

    let rect = CGRect(x: x, y: y, width: width, height: height).integral
    return rootView.convert(rect, from: nil)
  }

  private func resolvedUserInterfaceStyleFromFlutterTheme(from args: [String: Any]) -> UIUserInterfaceStyle {
    switch args["themeBrightness"] as? String {
    case "light":
      return .light
    case "dark":
      return .dark
    default:
      return .unspecified
    }
  }

  private func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func cleanupAnchorButton() {
    anchorButton?.removeFromSuperview()
    anchorButton = nil
    anchorButtonInstanceId = nil
  }

  private func disposeInstance(from args: Any?) {
    guard
      let dictionary = args as? [String: Any],
      let instanceId = dictionary["instanceId"] as? String,
      !instanceId.isEmpty
    else {
      return
    }

    if anchorButtonInstanceId == instanceId {
      cleanupAnchorButton()
    }
  }

  private func sendSelection(_ id: String, instanceId: String) {
    let channel = FlutterMethodChannel(
      name: "ios_adaptive_context_menu/instance_\(instanceId)",
      binaryMessenger: messenger
    )
    channel.invokeMethod("onSelected", arguments: ["id": id])
    cleanupAnchorButton()
  }
}

private struct MenuActionConfig {
  let id: String
  let title: String
  let iconImage: UIImage?
  let iconSystemName: String?
  let showTrailingCheckmark: Bool
  let isDestructive: Bool
  let isEnabled: Bool
}

private struct MenuSubmenuConfig {
  let title: String
  let iconImage: UIImage?
  let iconSystemName: String?
  let children: [MenuItemConfig]
}

private enum MenuItemConfig {
  case action(MenuActionConfig)
  case submenu(MenuSubmenuConfig)
  case divider
}

@available(iOS 14.0, *)
private extension IosSingleTapContextMenuPlugin {
  func makeElement(from item: MenuItemConfig, instanceId: String) -> UIMenuElement {
    switch item {
    case .action(let action):
      var attributes = UIMenuElement.Attributes()
      if action.isDestructive {
        attributes.insert(.destructive)
      }
      if !action.isEnabled {
        attributes.insert(.disabled)
      }

      let image = action.iconImage ?? action.iconSystemName.flatMap { UIImage(systemName: $0) }
      let state: UIMenuElement.State = action.showTrailingCheckmark ? .on : .off

      return UIAction(
        title: action.title,
        image: image,
        attributes: attributes,
        state: state
      ) { [weak self] _ in
        self?.sendSelection(action.id, instanceId: instanceId)
      }

    case .submenu(let submenu):
      let image = submenu.iconImage ?? submenu.iconSystemName.flatMap { UIImage(systemName: $0) }
      let children = buildMenuElements(from: submenu.children, instanceId: instanceId)
      return UIMenu(title: submenu.title, image: image, children: children)

    case .divider:
      return UIMenu(title: "", children: [])
    }
  }

  func buildMenuElements(from items: [MenuItemConfig], instanceId: String) -> [UIMenuElement] {
    let groups = buildGroups(from: items)
    if groups.count <= 1 {
      return groups.first?.map { makeElement(from: $0, instanceId: instanceId) } ?? []
    }

    return groups.map { group in
      UIMenu(
        title: "",
        options: [.displayInline],
        children: group.map { makeElement(from: $0, instanceId: instanceId) }
      )
    }
  }

  func buildGroups(from items: [MenuItemConfig]) -> [[MenuItemConfig]] {
    var groups: [[MenuItemConfig]] = [[]]

    for item in items {
      switch item {
      case .divider:
        if let last = groups.last, !last.isEmpty {
          groups.append([])
        }
      default:
        groups[groups.count - 1].append(item)
      }
    }

    return groups.filter { !$0.isEmpty }
  }

  func parseItems(from args: [String: Any]) -> [MenuItemConfig] {
    guard let rawItems = args["actions"] as? [[String: Any]] else {
      return []
    }
    return parseItems(rawItems)
  }

  func parseItems(_ rawItems: [[String: Any]]) -> [MenuItemConfig] {
    rawItems.compactMap { item in
      let type = (item["type"] as? String) ?? "action"

      if type == "divider" {
        return .divider
      }

      if type == "submenu" {
        guard
          let title = item["title"] as? String,
          !title.isEmpty
        else {
          return nil
        }

        let iconSystemName = item["iconSystemName"] as? String
        let iconData = (item["iconPngBytes"] as? FlutterStandardTypedData)?.data
        let iconImage = iconData.flatMap { UIImage(data: $0) }
        let rawChildren = item["children"] as? [[String: Any]] ?? []

        return .submenu(
          MenuSubmenuConfig(
            title: title,
            iconImage: iconImage,
            iconSystemName: iconSystemName,
            children: parseItems(rawChildren)
          )
        )
      }

      guard
        let id = item["id"] as? String,
        let title = item["title"] as? String,
        !id.isEmpty,
        !title.isEmpty
      else {
        return nil
      }

      let destructive = item["destructive"] as? Bool ?? false
      let enabled = item["enabled"] as? Bool ?? true
      let showTrailingCheckmark = item["showTrailingCheckmark"] as? Bool ?? false
      let iconSystemName = item["iconSystemName"] as? String
      let iconData = (item["iconPngBytes"] as? FlutterStandardTypedData)?.data
      let iconImage = iconData.flatMap { UIImage(data: $0) }

      return .action(
        MenuActionConfig(
          id: id,
          title: title,
          iconImage: iconImage,
          iconSystemName: iconSystemName,
          showTrailingCheckmark: showTrailingCheckmark,
          isDestructive: destructive,
          isEnabled: enabled
        )
      )
    }
  }
}

private final class NoHighlightButton: UIButton {
  override var isHighlighted: Bool {
    get { false }
    set {}
  }
}
