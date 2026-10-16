{{flutter_js}}
{{flutter_build_config}}

const status = document.getElementById('status');
function failed() {
  status.textContent = '加载中断，请检查网络后重试';
  document.getElementById('retry').hidden = false;
}
window.addEventListener('flutter-first-frame', () => document.getElementById('boot')?.remove(), { once: true });
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      status.textContent = '正在准备课程与社区…';
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) { failed(); console.error(error); }
  },
}).catch(failed);
