<span class="copyright-year">
    {% set current = date(Date.now(), "YYYY") %}
        &copy;
    {% if theme.since and theme.since != current %}
        {{ theme.since }} -
    {% endif %}
    {{ current }}
    <span class="footer-author">{{ config.author }}.</span>
    <span class="power-by">
        {{ __('footer.powered', '<a class="hexo-link" href="https://0xfe.com.cn/">0xFE</a>') }}
    </span>
    <script async src="//busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js">
    </script>

    <span class="post-meta-divider">|</span>
    <span id="busuanzi_container_site_pv">
        总访问量: <span id="busuanzi_value_site_pv"></span>次 |
    </span>
    <span id="busuanzi_container_site_uv">
        访客数<span id="busuanzi_value_site_uv"></span>人次 |<a href="http://beian.miit.gov.cn/">京ICP备19039702号</a>
    </span>
</span>
