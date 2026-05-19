(function() {
    console.log("HSB: Douyin Startup Script Loaded");

    // 1. Existing Logic: Click Full Screen / Start
    var douyinBtn = document.querySelector('.xgplayer-page-full-screen');
    if (douyinBtn) {
        var icon = douyinBtn.querySelector('.xgplayer-icon');
        if (icon) {
            icon.click();
        }
    }

    // 2. New Logic: Dismiss "Save User Info" Popup
    // "进入页面后总是弹出 保存用户信息的提示，需要模拟点击否"
    function dismissSaveInfoPopup() {
        console.log("HSB: Scanning for 'Save Info' popup...");
        
        // Keywords for "No" / "Cancel" / "Not Now"
        const keywords = ["取消", "以后再说", "不保存", "暂不", "拒绝"];
        
        // Strategy: Look for buttons or clickable elements containing these keywords
        const elements = document.querySelectorAll('div, button, span, a');
        
        for (let el of elements) {
            if (!el.innerText) continue;
            
            const text = el.innerText.trim();
            if (keywords.includes(text)) {
                 // Check visibility
                 if (el.offsetParent === null) continue;
                 
                 console.log(`HSB: Found dismissal button: ${text}, clicking...`);
                 el.click();
                 return true;
            }
        }
        return false;
    }

    // Poll for the popup
    let retries = 0;
    const maxRetries = 20; // Check for 10 seconds (20 * 500ms)
    
    const interval = setInterval(() => {
        if (dismissSaveInfoPopup()) {
            console.log("HSB: Popup dismissed.");
            clearInterval(interval);
        } else {
            retries++;
            if (retries >= maxRetries) {
                clearInterval(interval);
                console.log("HSB: Popup dismissal timed out.");
            }
        }
    }, 500);

})();
