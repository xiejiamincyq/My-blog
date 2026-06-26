<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" lang="zh-CN">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>虾米的博客 - RSS 订阅</title>
        <style>
          :root {
            color-scheme: light;
            --text: #16211f;
            --muted: #687672;
            --border: #d7e1dd;
            --link: #11695f;
            --surface: #ffffff;
            --page: #f5f7f6;
          }

          body {
            margin: 0;
            background: var(--page);
            color: var(--text);
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            line-height: 1.7;
          }

          main {
            box-sizing: border-box;
            width: min(760px, 100%);
            margin: 0 auto;
            padding: 40px 20px 56px;
          }

          h1 {
            margin: 0 0 12px;
            font-size: 30px;
            line-height: 1.2;
          }

          p {
            margin: 0 0 12px;
            color: var(--muted);
          }

          code {
            overflow-wrap: anywhere;
          }

          a {
            color: var(--link);
          }

          .intro {
            margin-bottom: 28px;
          }

          .item {
            margin: 16px 0;
            padding: 20px;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 8px;
          }

          .item h2 {
            margin: 0 0 8px;
            font-size: 20px;
            line-height: 1.35;
          }

          .item small {
            color: var(--muted);
          }
        </style>
      </head>
      <body>
        <main>
          <div class="intro">
            <h1>虾米的博客 - RSS 订阅</h1>
            <p>将此页面地址添加到 RSS 阅读器，即可订阅博客更新。</p>
            <p>订阅地址：<code><xsl:value-of select="concat(/rss/channel/link, 'rss.xml')"/></code></p>
          </div>

          <xsl:for-each select="/rss/channel/item">
            <article class="item">
              <h2>
                <a>
                  <xsl:attribute name="href"><xsl:value-of select="link"/></xsl:attribute>
                  <xsl:value-of select="title"/>
                </a>
              </h2>
              <p><xsl:value-of select="description"/></p>
              <small><xsl:value-of select="pubDate"/></small>
            </article>
          </xsl:for-each>
        </main>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
