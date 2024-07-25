var navBack = false;
var clearTimer: number | undefined;

window.addEventListener("popstate", onNavigatedBack);

function onNavigatedBack(this: Window, ev: PopStateEvent) {
  navBack = true;

  if (clearTimer) {
    clearTimeout(clearTimer);
  }

  clearTimer = setTimeout(() => {
    navBack = false;
    clearTimer = undefined;
  }, 1000);
}

export function getIsNavBack() {
  return navBack;
}
