# 版本
main

# 需求描述
调整Search界面和Shiori界面的表格界面。详见# UI文档改动。

# UI文档改动

### 1.2 尺寸、圆角、间距
#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 16px
--font-size-table: 14px
--font-size-table-header: 12px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px

### 2.17 Table Row
#### Content
Header Text Color: --color-text-muted
Header Font Size: --font-size-table-header
Header Font Weight: 500
Primary Text Color: --color-text-primary
Primary Text Font Weight: 500
Secondary Text Color: --color-text-muted
Secondary Text Font Weight: 400
Metadata Text Color: --color-text-muted
Metadata Text Font Weight: 400
Metadata Numeric Variant: tabular-nums
Interactive Text Color: --color-text-primary
Interactive Text Font Weight: 500
Columns: defined by each table layout
Tags: Chip / Tag

### 2.18 Sortable Header Cell
#### Content
Text Size: --font-size-table-header
Text Weight: 500
Text Color Default: --color-text-muted
Text Color Disabled: --color-text-disabled
Icon Default: --color-icon-default
Icon Disabled: --color-icon-disabled
Indicator Unsorted: chevrons-up-down
Indicator Asc: arrow-up
Indicator Desc: arrow-down

### 3.7 Search / Shiori Table Layout
Column Visual Priority:
  Cues:
    Role: primary content
    Applies To: Search / Shiori
    Text Color: --color-text-primary
    Font Weight: 500

  Display Title:
    Role: secondary context
    Applies To: Search / Shiori
    Text Color: --color-text-muted
    Font Weight: 400

  Date Added:
    Role: metadata
    Applies To: Shiori
    Text Color: --color-text-muted
    Font Weight: 400
    Numeric Variant: tabular-nums

  Time:
    Role: metadata
    Applies To: Search / Shiori
    Text Color: --color-text-muted
    Font Weight: 400
    Numeric Variant: tabular-nums