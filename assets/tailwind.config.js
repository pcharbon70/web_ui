/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./assets/elm/src/**/*.elm",
    "./priv/static/web_ui/*.html"
  ],
  theme: {
    extend: {
      colors: {
        phoenix: {
          primary: "#3b82f6",
          secondary: "#8b5cf6",
          success: "#10b981",
          danger: "#ef4444",
          warning: "#f59e0b"
        }
      }
    },
  },
  plugins: [],
  corePlugins: {
    preflight: false, // Don't apply Preflight base styles
  }
}
