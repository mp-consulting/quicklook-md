# Kitchen sink

Intro with **bold**, *italic*, ***both***, ~~strike~~, `code`, a [link](https://example.com "Example"), an autolink https://example.com/path?a=1&b=2, and an escaped \*star\*.
Hard break follows  
next line. Entities: &copy; &amp; &#x1F600;.

## Headings with *formatting* & "punctuation"

### Duplicate

### Duplicate

## Lists

- tight
- list
  1. nested ordered
  2. second

5. starts at five
6. six

- loose

- list

Tasks, tight and loose:

- [x] done
- [ ] todo

* [x] loose done

* [ ] loose todo

## Code

```python title="x.py"
def f(x):
    return x < 1 and "<tag>"
```

    indented code

## Quotes and alerts

> A plain quote
>
> > nested

> [!IMPORTANT]
> Read this.
>
> Twice.

> [!CAUTION]
>
> Careful.

## Table

| Left | Center | Right | None |
|:-----|:------:|------:|------|
| `a` | **b** | [c](#c) | d \| e |
| 1 | 2 |

## Media and HTML

![Logo *alt*](images/logo.png "The logo")

<p align="center">
  <img src="images/banner.png" width="200" alt="Banner">
</p>

Inline <kbd>Cmd</kbd> + <kbd>Space</kbd>.

<details>
<summary>More</summary>

Hidden **content**.

</details>

## Footnotes

Claim[^1] and another[^long-note] and again[^1].

[^1]: First note.
[^long-note]: Second note with `code`.

---

The end.
