(function() {
    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async function selectHighResolution() {
        const claritySetting = document.querySelector('.xgplayer-playclarity-setting');
        if (!claritySetting) {
            return;
        }

        const gear = claritySetting.querySelector('.gear');
        if (gear) {
            const mouseOverEvent = new MouseEvent('mouseover', {
                'view': window,
                'bubbles': true,
                'cancelable': true
            });
            const mouseEnterEvent = new MouseEvent('mouseenter', {
                'view': window,
                'bubbles': true,
                'cancelable': true
            });
            gear.dispatchEvent(mouseOverEvent);
            gear.dispatchEvent(mouseEnterEvent);
        }

        await sleep(500);

        const items = claritySetting.querySelectorAll('.item');
        if (!items || items.length === 0) {
            return;
        }

        let bestItem = null;
        let maxRes = 0;

        for (let item of items) {
            const text = item.innerText;
            if (!text) continue;

            if (item.classList.contains('selected') && !text.includes('智能')) {
            }

            let currentRes = 0;
            if (text.includes("4K") || text.includes("Ultra")) currentRes = 4000;
            else if (text.includes("2K")) currentRes = 2000;
            else if (text.includes("1080")) currentRes = 1080;
            else if (text.includes("720")) currentRes = 720;
            else if (text.includes("高清")) currentRes = 700; 
            else if (text.includes("标清")) currentRes = 480;

            if (currentRes > maxRes) {
                maxRes = currentRes;
                bestItem = item;
            }
        }

        if (bestItem) {
            if (bestItem.classList.contains('selected')) {
            } else {
                bestItem.click();
            }
        } else {
            if (items.length > 0 && !items[0].classList.contains('selected')) {
                 items[0].click();
            }
        }
        
        if (gear) {
             const mouseLeaveEvent = new MouseEvent('mouseleave', {
                'view': window,
                'bubbles': true,
                'cancelable': true
            });
            gear.dispatchEvent(mouseLeaveEvent);
        }
    }

    setTimeout(selectHighResolution, 3000);
    setInterval(selectHighResolution, 10000);

})();
