import type { ModelRef, SuggestedPlugin } from "./types";
import { t } from "../i18n";
import { readDenBootstrapConfig } from "./lib/den";

export const MODEL_PREF_KEY = "openwork.defaultModel";
export const SESSION_MODEL_PREF_KEY = "openwork.sessionModels";
export const THINKING_PREF_KEY = "openwork.showThinking";
export const VARIANT_PREF_KEY = "openwork.modelVariant";
export const LANGUAGE_PREF_KEY = "openwork.language";
export const HIDE_TITLEBAR_PREF_KEY = "openwork.hideTitlebar";

export const DEFAULT_MODEL: ModelRef = {
  providerID: "openrouter",
  modelID: "anthropic/claude-sonnet-4.6",
};

export const SUGGESTED_PLUGINS: SuggestedPlugin[] = [];

export type ExtensionKind = "mcp" | "plugin" | "skill" | "ui-control" | "extension";

export type McpDirectoryInfo = {
  id?: string;
  /** Display name shown in the UI. */
  name: string;
  /** Safe server name for opencode.jsonc (alphanumeric, - and _ only). Auto-derived from name if omitted. */
  serverName?: string;
  description: string;
  url?: string;
  type?: "remote" | "local";
  command?: string[];
  oauth: boolean;
  /** Extension category for UI grouping. Defaults to "mcp". */
  kind?: ExtensionKind;
  /** Simple Icons slug for brand icon (e.g. "notion", "stripe", "figma"). */
  iconSlug?: string;
  /** Direct icon URL (e.g. local SVG). Takes priority over iconSlug. */
  iconSrc?: string;
  /** Prompt inserted from the composer extension picker. */
  composerPrompt?: string;
  /** Whether OpenWork should show this extension as enabled before user setup. */
  defaultEnabled?: boolean;
};

/** Derive a safe MCP server name from a display name or explicit serverName. */
export function getMcpServerName(entry: McpDirectoryInfo): string {
  if (entry.serverName) return entry.serverName;
  return entry.name
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "") || "mcp";
}

export const MCP_QUICK_CONNECT: McpDirectoryInfo[] = [
  {
    get name() { return t("mcp.quick_connect_notion_title"); },
    serverName: "notion",
    get description() { return t("mcp.quick_connect_notion_desc"); },
    url: "https://mcp.notion.com/mcp",
    type: "remote",
    oauth: true,
    kind: "mcp",
    iconSlug: "notion",
    iconSrc: "/ext-notion.svg",
  },
  {
    get name() { return t("mcp.quick_connect_linear_title"); },
    serverName: "linear",
    get description() { return t("mcp.quick_connect_linear_desc"); },
    url: "https://mcp.linear.app/mcp",
    type: "remote",
    oauth: true,
    kind: "mcp",
    iconSlug: "linear",
    iconSrc: "/ext-linear.svg",
  },
  {
    get name() { return t("mcp.quick_connect_sentry_title"); },
    serverName: "sentry",
    get description() { return t("mcp.quick_connect_sentry_desc"); },
    url: "https://mcp.sentry.dev/mcp",
    type: "remote",
    oauth: true,
    kind: "mcp",
    iconSlug: "sentry",
    iconSrc: "/ext-sentry.svg",
  },
  {
    get name() { return t("mcp.quick_connect_stripe_title"); },
    serverName: "stripe",
    get description() { return t("mcp.quick_connect_stripe_desc"); },
    url: "https://mcp.stripe.com",
    type: "remote",
    oauth: true,
    kind: "mcp",
    iconSlug: "stripe",
    iconSrc: "/ext-stripe.svg",
  },
  {
    get name() { return t("mcp.quick_connect_context7_title"); },
    serverName: "context7",
    get description() { return t("mcp.quick_connect_context7_desc"); },
    url: "https://mcp.context7.com/mcp",
    type: "remote",
    oauth: false,
    kind: "mcp",
    iconSlug: "semanticscholar",
    iconSrc: "/ext-context7.svg",
  },
  {
    get name() { return t("mcp.quick_connect_openwork_cloud_title"); },
    serverName: "openwork-cloud",
    get description() { return t("mcp.quick_connect_openwork_cloud_desc"); },
    get url() {
      try {
        return `${readDenBootstrapConfig().baseUrl.replace(/\/+$/, "")}/mcp`;
      } catch {
        return "https://app.openworklabs.com/mcp";
      }
    },
    type: "remote",
    oauth: true,
    kind: "mcp",
    iconSrc: "/openwork-mark.svg",
  },
  {
    get name() { return t("mcp.quick_connect_openwork_ui_title"); },
    serverName: "openwork-ui",
    get description() { return t("mcp.quick_connect_openwork_ui_desc"); },
    type: "local",
    // Dev builds replace this with the local checkout path before writing config.
    command: ["npx", "-y", "openwork-ui-mcp"],
    oauth: false,
    kind: "ui-control",
    iconSrc: "/openwork-mark.svg",
  },
  {
    id: "openwork-browser",
    name: "OpenWork Browser",
    serverName: "openwork-browser",
    description: "Automate the built-in browser panel that stays visible inside OpenWork.",
    oauth: false,
    kind: "extension",
    iconSrc: "/openwork-mark.svg",
    composerPrompt: "Use the OpenWork Browser extension to ",
    defaultEnabled: true,
  },
  {
    id: "chrome-browser",
    name: "Chrome",
    serverName: "chrome-browser",
    description: "Use your real Chrome session when a task needs cookies, sign-ins, or extensions.",
    oauth: false,
    kind: "extension",
    iconSlug: "googlechrome",
    composerPrompt: "Use the Chrome extension to ",
    defaultEnabled: true,
  },
  {
    id: "openai-image-gen",
    name: "OpenAI Image Gen",
    serverName: "openai-image-gen",
    description: "Generate image artifacts with gpt-image-2.",
    oauth: false,
    kind: "extension",
    iconSrc: "/ext-openai.svg",
    composerPrompt: "Use the OpenAI Image Gen extension to ",
  },
  {
    id: "ollama",
    name: "Ollama",
    serverName: "ollama",
    description: "Local model provider at http://localhost:11434.",
    oauth: false,
    kind: "extension",
    iconSrc: "/ext-ollama.svg",
    composerPrompt: "Use the Ollama extension to ",
  },
];

export const OPENWORK_EXTENSION_CATALOG = MCP_QUICK_CONNECT.filter((entry) => entry.kind === "extension");
