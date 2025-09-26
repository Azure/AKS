import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'AKS Engineering Blog',
  tagline: 'Azure Kubernetes Service Engineering and Product Management Team',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://blog.aks.azure.com',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',
  trailingSlash: false,

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'pauldotyu', // Usually your GitHub org/user name.
  projectName: 'aks-blog', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: false,
        blog: {
          routeBasePath: '/',
          showReadingTime: true,
          blogSidebarCount: 'ALL',
          blogSidebarTitle: 'Recent posts',
          postsPerPage: 'ALL',
          archiveBasePath: null,
          blogDescription: 'AKS Engineering Blog - Insights from the Azure Kubernetes Service team',
          blogTitle: 'AKS Engineering Blog',
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
            // Override feed title to avoid duplicated 'Blog'
            title: 'AKS Engineering Blog',
          },
          editUrl: 'https://github.com/Azure/AKS',
          onInlineTags: 'warn',
          onInlineAuthors: 'warn',
          onUntruncatedBlogPosts: 'warn',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  clientModules: [
    require.resolve('./src/js/consentModule.ts'),
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/social-card.jpg',
    navbar: {
      title: 'AKS Engineering Blog',
      logo: {
        alt: 'AKS Logo',
        src: 'img/logo.svg',
      },
      items: [
        { to: '/', label: 'Posts', position: 'left', exact: true },
        { to: '/tags', label: 'Tags', position: 'left' },
        {
          type: 'dropdown',
          label: 'Resources',
          position: 'left',
          items: [
            {
              label: 'Documentation',
              href: 'https://learn.microsoft.com/azure/aks',
            },
            {
              label: 'Architecture Center',
              href: 'https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-start-here',
            },
            {
              label: 'Learning Paths',
              href: 'https://learn.microsoft.com/training/browse/?products=azure-kubernetes-service',
            },
            {
              label: 'Troubleshooting Guides',
              href: 'https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/welcome-azure-kubernetes',
            },
            {
              label: 'FAQ',
              href: 'https://learn.microsoft.com/azure/aks/faq',
            },
          ],
        },
        {
          href: 'https://github.com/Azure/AKS/releases',
          label: 'Releases',
          position: 'right',
        },
        {
          href: 'https://github.com/orgs/Azure/projects/685',
          label: 'Roadmap',
          position: 'right',
        },
        {
          href: 'https://github.com/Azure/AKS',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Resources',
          items: [
            {
              label: 'Documentation',
              href: 'https://learn.microsoft.com/azure/aks',
            },
            {
              label: 'Architecture Center',
              href: 'https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-start-here',
            },
            {
              label: 'Learning Paths',
              href: 'https://learn.microsoft.com/training/browse/?products=azure-kubernetes-service',
            },
            {
              label: 'Troubleshooting Guides',
              href: 'https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes/welcome-azure-kubernetes',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/Azure/AKS',
            },
            {
              label: 'Webinars',
              href: '/webinars',
            },
            {
              label: 'X (Twitter)',
              href: 'https://twitter.com/theakscommunity',
            },
            {
              label: 'YouTube',
              href: 'https://www.youtube.com/@theakscommunity',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Roadmap',
              href: 'https://github.com/orgs/Azure/projects/685',
            },
            {
              label: 'FAQ',
              href: 'https://learn.microsoft.com/azure/aks/faq',
            },
            {
              label: 'RSS Feed',
              // Use absolute URL so Docusaurus broken link checker treats it as external (feeds aren't routes)
              href: 'https://blog.aks.azure.com/rss.xml',
            },
            {
              label: 'Contact',
              href: 'mailto:brian.redmond@microsoft.com',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} AKS Engineering Blog. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
