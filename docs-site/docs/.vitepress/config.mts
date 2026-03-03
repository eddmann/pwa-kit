import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'en-US',
  title: 'PWAKit',
  description: 'Wrap your Progressive Web App in a native iOS shell with a typed JavaScript bridge.',
  cleanUrls: true,
  lastUpdated: true,
  themeConfig: {
    logo: '/logo.png',
    siteTitle: 'PWAKit',
    nav: [
      { text: 'Get Started', link: '/guide/getting-started' },
      { text: 'Configuration', link: '/configuration/overview' },
      { text: 'SDK', link: '/sdk/overview' },
      { text: 'CLI', link: '/cli/overview' },
      { text: 'Help', link: '/help/troubleshooting' },
      { text: 'GitHub', link: 'https://github.com/eddmann/pwa-kit' }
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Get Started',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Install Requirements', link: '/guide/requirements' },
            { text: 'Run Your First Build', link: '/guide/first-build' },
            { text: 'Development Workflow', link: '/guide/development-workflow' },
            { text: 'Kitchen Sink Demo', link: '/guide/kitchen-sink-demo' }
          ]
        }
      ],
      '/configuration/': [
        {
          text: 'Basics',
          items: [
            { text: 'Overview', link: '/configuration/overview' },
            { text: 'Configuration Basics', link: '/configuration/basics' },
            { text: 'Full pwa-config.json', link: '/configuration/full-pwa-config' },
            { text: 'Config Schema (Quick)', link: '/configuration/config-schema' }
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Origins and URL Rules', link: '/configuration/origins' },
            { text: 'Info.plist and Entitlements', link: '/configuration/ios-capabilities' },
            { text: 'Syncing Config', link: '/configuration/sync' },
            { text: 'Advanced Usage', link: '/configuration/advanced-usage' }
          ]
        }
      ],
      '/sdk/': [
        {
          text: 'SDK',
          items: [
            { text: 'SDK Overview', link: '/sdk/overview' },
            { text: 'Runtime Detection', link: '/sdk/runtime-detection' },
            { text: 'Web API Modules', link: '/sdk/web-api-modules' },
            { text: 'iOS Modules', link: '/sdk/ios-modules' },
            { text: 'Custom Module Integration', link: '/sdk/custom-modules' },
            { text: 'Bridge API', link: '/sdk/bridge-api' },
            { text: 'Error Handling', link: '/sdk/errors' }
          ]
        }
      ],
      '/cli/': [
        {
          text: 'CLI',
          items: [
            { text: 'CLI Overview', link: '/cli/overview' },
            { text: 'init Command', link: '/cli/init' },
            { text: 'sync Command', link: '/cli/sync' },
            { text: 'CLI Reference', link: '/cli/reference' }
          ]
        }
      ],
      '/core/': [
        {
          text: 'Core Concepts',
          items: [
            { text: 'Architecture', link: '/core/architecture' },
            { text: 'Custom Native Modules', link: '/core/custom-modules' },
            { text: 'Framework Comparison', link: '/core/comparison' }
          ]
        }
      ],
      '/help/': [
        {
          text: 'Help',
          items: [
            { text: 'Troubleshooting', link: '/help/troubleshooting' },
            { text: 'FAQ', link: '/help/faq' }
          ]
        }
      ]
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/eddmann/pwa-kit' }],
    search: { provider: 'local' },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © Edd Mann'
    }
  }
})
