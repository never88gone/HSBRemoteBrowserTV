(function() {
    const CONFIG = {
        account: "", 
        password: ""
    };

    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    function triggerInput(element, value) {
        if (!element) return;
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
        nativeInputValueSetter.call(element, value);
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    async function autoLogin() {
        const loginPanel = document.getElementById("login-panel-new") || document.querySelector('.douyin_login_new_class');
        if (!loginPanel) {
            const headerLoginBtn = document.querySelector('#douyin-header-menuCt button p.r2P1NdJa') 
                                   || document.querySelector('#douyin-header-menuCt button') 
                                   || findElementByText("button", "登录") 
                                   || findElementByText("p", "登录");

            if (headerLoginBtn) {
                 headerLoginBtn.click();
                 
                 let maxRetries = 10;
                 while (maxRetries > 0) {
                     await sleep(500);
                     const panel = document.getElementById("login-panel-new") || document.querySelector('.douyin_login_new_class');
                     if (panel) {
                         break;
                     }
                     maxRetries--;
                 }
            }
        }

        const passwordTab = findElementByText("span", "密码登录");
        if (passwordTab) {
            passwordTab.click();
        }

        await sleep(1000);

        const accountInput = document.querySelector('input[name="mobile"]') || 
                           document.querySelector('input[name="text"]') || 
                           document.querySelector('input[placeholder*="手机"]');
        
        if (accountInput) {
            triggerInput(accountInput, CONFIG.account);
        }

        const passwordInput = document.querySelector('input[type="password"]') || 
                            document.querySelector('input[name="password"]');

        if (passwordInput) {
            triggerInput(passwordInput, CONFIG.password);
        }

        await sleep(500);

        const loginBtn = document.getElementById("douyin_login_comp_btn_id") || 
                         findElementByText("div", "登录/注册") ||
                         findElementByText("div", "登录");

        if (loginBtn) {
            loginBtn.click();
        }
    }

    function findElementByText(tagName, text) {
        const elements = document.querySelectorAll(tagName);
        for (let el of elements) {
            if (el.innerText && el.innerText.includes(text)) {
                return el;
            }
        }
        return null;
    }

    setTimeout(autoLogin, 2000);

})();
