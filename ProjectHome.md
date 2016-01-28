這個腳本是使用shell編寫，為了快速在生產環境上部署LNMP/LAMP/LANMP（Linux、Nginx/Tengine、MySQL
/MariaDB/Percona、PHP）,適用於CentOS/Redhat 5+、Debain 6+和Ubuntu 12+
<br>
<br>本腳本適用環境：<br>
<br>
<br>系統支援：CentOS/Redhat/Debain/Ubuntu<br>
<br>記憶體要求：≥1.5GB<br>
<br>硬碟空間要求：8GB以上的剩餘空間<br>
<br>伺服器必須設定好軟體來源和可連接網際網路(使用外部IP)<br>
<br>必須具有系統 root 權限<br>
<br>建議使用乾淨系統全新安裝<br>
<br>更新日期：2015年01月22日<br>
<br>
<br>腳本特性：<br>
<br>
<br>持續不斷更新<br>
<br>(重點)針對台灣、香港、澳門地區使用者習慣特別優化，也適用於中國與海外地區<br>
<br>源碼編譯安裝，大多數源碼是最新stable版，並從官方網址下載<br>
<br>一些安全優化<br>
<br>提供多個資料庫版本(MySQL-5.6, MySQL-5.5, MariaDB-10.0, MariaDB-5.5, Percona-5.6, Percona-5.5)<br>
<br>提供多個PHP版本(php-5.3, php-5.4, php-5.5,php-5.6,php-7/phpng(alpha)#News)<br>
<br>提供Nginx、Tengine<br>
<br>提供多個Apache版本（Apache-2.4，Apache-2.2）<br>
<br>根據自己需求安裝PHP快取加速器，提供ZendOPcache、xcache、apcu、eAccelerator、ionCube和ZendGuardLoader（php-5.4、php-5.3 PHP源碼加密）<br>
<br>根據自己需求安裝Pureftpd、phpMyAdmin<br>
<br>根據自己需求安裝memcached、redis<br>
<br>根據自己需求可使用tcmalloc或者jemalloc優化MySQL、Nginx<br>
<br>提供添加虛擬主機腳本<br>
<br>提供Nginx/Tengine、PHP、Redis、phpMyAdmin升級腳本<br>
<br>提供本地備份和遠程備份（伺服器之間rsync）腳本<br>
<br>Github地址：<a href='https://github.com/a950216t/lampd'>https://github.com/a950216t/lampd</a>
<br>LNMP問題反饋論壇：<a href='http://bbs.myxnova.com'>http://bbs.myxnova.com</a>
<br>LNMP最新源碼一鍵安裝腳本問題反饋請加QQ群： 276041013<br>
<br>
<br>安裝步驟：<br>
<br>注意： 腳本會自動清除iptables原有設定，請先安裝完lampd，再改ssh連接埠等操作<br>
<br>
<br>yum -y install wget screen # for CentOS/Redhat<br>
<br>#apt-get -y install wget screen # for Debian/Ubuntu<br>
<br>cd lampd #如果需要修改資料夾(安裝、資料儲存、Nginx記錄)，請修改options.conf檔案<br>
<br>screen -S lampd # 如果網路出現中斷，可以執行命令<code>screen -r lampd</code>重新連線安裝視窗<br>
<br>./install.sh<br>
<br>
<br>添加虛擬主機:<br>
<br>cd ~/lampd # 必須進入lampd資料夾下執行<br>
<br>./vhost.sh<br>
<br>
<br>資料備份:<br>
<br>cd ~/lnmp # 必須進入lampd資料夾下執行<br>
<br>./backup_setup.sh # 備份參數設定<br>
<br>./backup.sh # 立即執行備份<br>
<br>crontab -e # 可添加到計劃任務，如每天凌晨1點自動備份<br>
<br>0 1  <b>cd ~/lnmp;./backup.sh  > /dev/null 2>&1 &<br></b><br>
<br>管理服務:<br>
<br>Nginx/Tengine:<br>
<br>
<br>service nginx {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}<br>
<br>MySQL/MariaDB/Percona:<br>
<br>
<br>service mysqld {start|stop|restart|reload|force-reload|status}<br>
<br>PHP:<br>
<br>
<br>service php-fpm {start|stop|force-quit|restart|reload|status}<br>
<br>Apache:<br>
<br>
<br>service httpd {start|restart|graceful|graceful-stop|stop}<br>
<br>Pure-Ftpd:<br>
<br>
<br>service pureftpd {start|stop|restart|condrestart|status}<br>
<br>Redis:<br>
<br>
<br>service redis-server {start|stop|status|restart|condrestart|try-restart|reload|force-reload}<br>
<br>Memcached:<br>
<br>
<br>service memcached {start|stop|status|restart|reload|force-reload}<br>
<br>
<br>版本升級：<br>
<br>cd ~/lnmp # 必須進入lampd資料夾下執行<br>
<br>./upgrade_php.sh #升級PHP<br>
<br>./upgrade_web.sh #升級Nginx/Tengine<br>
<br>./upgrade_redis.sh #升級Redis<br>
<br>./upgrade_phpmyadmin.sh #升級phpMyAdmin<br>
<br>
<br>刪除lampd：<br>
<br>cd ~/lnmp # 必須進入lampd資料夾下執行<br>
<br>./uninstall.sh<br>
<br>
<br>重裝lampd：<br>
<br>cd ~/lampd # 必須進入lampd資料夾下執行<br>
<br>./uninstall.sh  #備份資料；刪除<br>
<br>./install.sh    #再次安裝