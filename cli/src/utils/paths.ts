import path from 'node:path';

export function projectPaths(projectRoot: string) {
  const src = path.join(projectRoot, 'src', 'PWAKit');
  const resources = path.join(src, 'Resources');
  const assets = path.join(resources, 'Assets.xcassets');

  return {
    projectRoot,
    configFile: path.join(resources, 'pwa-config.json'),
    configExample: path.join(resources, 'pwa-config.example.json'),
    infoPlist: path.join(src, 'Info.plist'),
    pbxproj: path.join(projectRoot, 'PWAKitApp.xcodeproj', 'project.pbxproj'),
    iconSource: path.join(resources, 'AppIcon-source.png'),
    assets,
    launchBackground: path.join(assets, 'LaunchBackground.colorset', 'Contents.json'),
    accentColor: path.join(assets, 'AccentColor.colorset', 'Contents.json'),
    appIcon: path.join(assets, 'AppIcon.appiconset', 'AppIcon.png'),
    launchIcon1x: path.join(assets, 'LaunchIcon.imageset', 'LaunchIcon.png'),
    launchIcon2x: path.join(assets, 'LaunchIcon.imageset', 'LaunchIcon@2x.png'),
    launchIcon3x: path.join(assets, 'LaunchIcon.imageset', 'LaunchIcon@3x.png'),
  };
}

export type ProjectPaths = ReturnType<typeof projectPaths>;
