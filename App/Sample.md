---
title: Sample document
tags: [markdown, quicklook]
---

# Markdown preview

This is how **Markdown** files look in Quick Look: *emphasis*, ~~strikethrough~~, `inline code` and [links](https://commonmark.org).

> [!NOTE]
> GitHub-style alerts are supported.

> [!WARNING]
> So are warnings, tips, important notes and cautions.

## Lists

- Tight list item
- Another one
  - Nested item

1. First
2. Second

- [x] Task done
- [ ] Task pending

## Code

```swift
struct Greeting {
    let name: String
    func message() -> String { "Hello, \(name)!" }
}
```

## Table

| Feature       | Supported | Notes              |
|:--------------|:---------:|-------------------:|
| Tables        |    ✓      | with alignment     |
| Task lists    |    ✓      | read-only          |
| Local images  |    ✓      | embedded           |

---

<details>
<summary>Raw HTML works too</summary>

Press <kbd>Space</kbd> in Finder.

</details>
