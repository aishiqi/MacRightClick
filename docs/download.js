const buttons = [
  document.getElementById("download"),
  document.getElementById("download-hero"),
  document.getElementById("download-bottom"),
].filter(Boolean);

const meta = document.getElementById("meta");

fetch("https://api.github.com/repos/aishiqi/MacRightClick/releases/latest")
  .then((response) => (response.ok ? response.json() : Promise.reject()))
  .then((release) => {
    const asset = (release.assets || []).find((item) => item.name.endsWith(".dmg"));
    if (asset) {
      buttons.forEach((button) => {
        button.href = asset.browser_download_url;
      });
    }
    const version = (release.tag_name || "").replace(/^v/, "") || "1.0.0";
    meta.textContent = `Version ${version} · Drag to Applications`;
  })
  .catch(() => {});
