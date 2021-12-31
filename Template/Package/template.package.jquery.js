
    var dehtmlToReplace = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
    };
    function dehtml(s,br) {
        if (!s) return s;
        s = String(s).replace(/[&<>\"]/g, function(tag) {
            return dehtmlToReplace[tag] || tag;
        });
        if (br) {
            s = String(s).replace(/\n/g, '<br />');
            s = String(s).replace(/[\r\n]/g, '');
        }
        return s;
    }
    
    String.prototype.dehtml = function(s,br){
        if (!s) return s;
        s = String(s).replace(/[&<>\"]/g, function(tag) {
            return dehtmlToReplace[tag] || tag;
        });
        if (br) {
            s = String(s).replace(/\n/g, '<br />');
            s = String(s).replace(/[\r\n]/g, '');
        }
        return s;
    };

    var formatRegExp = /%[sd%]/g;
    function StringFormat(){
        var i = 0;
        var args = arguments;
        var s = Array(args).shift();
        var len = args.length;
        
        return String(s).replace(formatRegExp, function (x) {
            if (x === '%%') return '%';
            if (i >= len) return x;
            switch (x) {
                case '%s':
                    return String(args[i++]);
                case '%d':
                    return Number(args[i++]);
                default:
                    return x;
            }
        });
    }
    String.prototype.format = function(){
        var s = this;
        var i = 0;
        var args = arguments;
        var len = args.length;
        
        return String(s).replace(formatRegExp, function (x) {
            if (x === '%%') return '%';
            if (i >= len) return x;
            switch (x) {
                case '%s':
                    return String(args[i++]);
                case '%d':
                    return Number(args[i++]);
                default:
                    return x;
            }
        });
    };
    
    
    
    /* Новый формат ajax-обновлений */
    var ajaxUpdater = {};
    var ajaxUpdateElement = null; // callback при обновлении блока
    /* Третий вариант ajax-обновлений */
    var ajaxUpdaterKey;
    var ajaxUpdaterUrl;
    var ajaxUpdaterReqHnd;
    function ajaxUpdaterReply(data) {
        if (!data) return;
        if (!Object.keys( data ).length) return;
        for (var key in data) {
            var d = data[key];
            var updid = d.shift();
            var upd = ajaxUpdater[updid];
            if (!upd) continue;
            
            d.unshift(key);
            console.log('update: ', key, d);
            upd.apply(this, d);
        }
    }
    function ajaxUpdaterReqjQuery() {
        if (!ajaxUpdaterKey || !ajaxUpdaterUrl || ajaxUpdaterReqHnd) return;
        ajaxUpdaterReqHnd = $.ajax({
            url: ajaxUpdaterUrl, // URL-адрес Perl-сценария
            dataType: 'json',
            method: 'POST',
            success: ajaxUpdaterReply,
            complete: function () {
                ajaxUpdaterReqHnd = null;
                ajaxUpdaterReq();
            }
        });
    }
    function ajaxUpdaterReq() {
        if (!ajaxUpdaterKey || !ajaxUpdaterUrl || ajaxUpdaterReqHnd) return;
        var xhr = new XMLHttpRequest();
        
        xhr.responseType = 'json';
        xhr.onreadystatechange = function() {
            if (this.readyState != 4) return;
        
            if (this.status == 200) {
                ajaxUpdaterReply(this.response);
            }
        
            ajaxUpdaterReq();
        }
        xhr.open("GET", ajaxUpdaterUrl, true);
        xhr.send();
    }
    function ajaxUpdaterElement(id) {
        var $el = $(id);
        if ($el.data('ajaxelid')) {
            return $el.eq(0);
        }
        var $el1 = $el.find('[data-ajaxelid]');
        if ($el1.length > 0) {
            return $el1.eq(0);
        }
        $el1 = $el.closest('[data-ajaxelid]');
        if ($el1.length > 0) {
            return $el1.eq(0);
        }
        
        return 0;
    }
    function ajaxUpdaterElementPause(id) {
        var el = ajaxUpdaterElement(id);
        if (!el) return;
        if (!ajaxUpdaterKey || !ajaxUpdaterUrl) return;
        var elid = $(el).data('ajaxelid');
        if (!elid) return;
        
        return $.ajax({
            url: ajaxUpdaterUrl, // URL-адрес Perl-сценария
            dataType: 'json',
            method: 'POST',
            data: { pause: elid },
            success: function(data) {
                if (data && data.error)
                    console.log('Error on update \''+elid+'\': ' + data.error);
                else
                    console.log('Pause OK: \''+elid+'\'');
            },
        });
    }
    function ajaxUpdaterElementResume(id) {
        var el = ajaxUpdaterElement(id);
        if (!el) return;
        if (!ajaxUpdaterKey || !ajaxUpdaterUrl) return;
        var elid = $(el).data('ajaxelid');
        if (!elid) return;
        
        return $.ajax({
            url: ajaxUpdaterUrl, // URL-адрес Perl-сценария
            dataType: 'json',
            method: 'POST',
            data: { resume: elid },
            success: function(data) {
                if (data && data.error)
                    console.log('Error on update \''+elid+'\': ' + data.error);
                else
                    console.log('Resume OK: \''+elid+'\'');
            },
        });
    }
    function ajaxUpdaterInit(key, url) {
        ajaxUpdaterKey = key;
        ajaxUpdaterUrl = url;
        ajaxUpdaterReq();
    }
    
