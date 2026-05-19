(function() {
    function findAndClickAutoPlay() {
        const autoPlayIcon = document.querySelector('.xgplayer-autoplay-setting');
        if (autoPlayIcon) {
            const switchBtn = autoPlayIcon.querySelector('.xg-switch');
            if (switchBtn) {
                switchBtn.click();
            } else {
                autoPlayIcon.click();
            }
            return;
        }

        const dataE2E = document.querySelector('[data-e2e="video-player-auto-play"]');
        if (dataE2E) {
            dataE2E.click();
            return;
        }

        const titles = document.querySelectorAll('.xgplayer-setting-title');
        for (let title of titles) {
            if (title.innerText && title.innerText.includes("连播")) {
                const container = title.closest('.xgplayer-autoplay-setting') || title.closest('.xg-icon');
                if (container) {
                    container.click();
                } else {
                    title.click();
                }
                return;
            }
        }
    }

    findAndClickAutoPlay();
    
    let retries = 0;
    const interval = setInterval(() => {
        retries++;
        if (retries > 5) {
            clearInterval(interval);
        } else {
            findAndClickAutoPlay();
        }
    }, 1000);

})();
