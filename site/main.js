(async () => {
  const meta = document.getElementById('build-meta');
  const size = document.getElementById('apk-size');
  try {
    const res = await fetch('https://api.github.com/repos/edwinrojo/peam/releases/tags/latest-apk');
    if (!res.ok) return;
    const release = await res.json();
    const apk = (release.assets || []).find((a) => a.name.endsWith('.apk'));
    const built = new Date((apk && apk.updated_at) || release.published_at);
    const date = built.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
    const commit = (release.target_commitish || '').slice(0, 7);
    meta.textContent = `Built by GitHub Actions on ${date}${commit ? ` · commit ${commit}` : ''} · Android 7.0 or newer`;
    if (apk) size.textContent = `${(apk.size / 1048576).toFixed(0)} MB`;
  } catch (_) {
    // Offline or rate-limited: keep the static text.
  }
})();
