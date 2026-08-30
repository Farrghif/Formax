import { useRef, useEffect } from 'react'
import ReactQuill, { Quill } from 'react-quill-new'
import 'react-quill-new/dist/quill.snow.css'
import katex from 'katex'
import 'katex/dist/katex.min.css'
import hljs from 'highlight.js'
import 'highlight.js/styles/atom-one-dark.min.css'
import ImageResize from '@mgreminger/quill-image-resize-module'

if (typeof window !== 'undefined') {
  window.katex = katex
  window.hljs = hljs
}

// Register custom fonts
const Font = Quill.import('formats/font')
Font.whitelist = [
  false,
  'inter',
  'roboto',
  'poppins',
  'montserrat',
  'open-sans',
  'lato',
  'nunito',
  'raleway',
  'source-code-pro',
  'fira-code',
  'jetbrains-mono',
  'arial',
  'georgia',
  'times-new-roman',
  'courier-new',
  'comic-sans',
]
Quill.register(Font, true)

// Register custom sizes
const Size = Quill.import('formats/size')
Size.whitelist = ['10px', '12px', '14px', '16px', '18px', '20px', '24px', '28px', '32px', '36px', '48px']
Quill.register(Size, true)

// Register image resize module
Quill.register('modules/imageResize', ImageResize)

// ── Custom Audio Blot ────────────────────────────────────────────────────────
const BlockEmbed = Quill.import('blots/block/embed')

class AudioBlot extends BlockEmbed {
  static create(url) {
    const node = super.create()
    node.setAttribute('controls', true)
    node.setAttribute('src', url)
    node.setAttribute('style', 'width:100%;margin:8px 0;border-radius:8px;')
    return node
  }

  static value(node) {
    return node.getAttribute('src')
  }
}
AudioBlot.blotName = 'audio'
AudioBlot.tagName = 'audio'
Quill.register(AudioBlot)
// ─────────────────────────────────────────────────────────────────────────────

// Full toolbar for form description
const FULL_MODULES = {
  toolbar: {
    container: [
      [{ font: Font.whitelist }, { size: Size.whitelist }, { header: [1, 2, 3, false] }],
      ['bold', 'italic', 'underline', 'strike'],
      [{ color: [] }, { background: [] }],
      ['code-block', 'blockquote'],
      [{ list: 'ordered' }, { list: 'bullet' }, { align: [] }],
      ['link', 'image', 'video', 'audio'],
      ['formula'],
      ['clean'],
    ],
    handlers: {
      audio: function () {
        const quill = this.quill
        const url = prompt('Masukkan URL audio (mp3, ogg, wav):')
        if (!url || !url.trim()) return
        const range = quill.getSelection(true)
        quill.insertEmbed(range.index, 'audio', url.trim(), 'user')
        quill.setSelection(range.index + 1, 0)
      },
    },
  },
  syntax: { hljs },
  imageResize: {
    modules: ['Resize', 'DisplaySize'],
    minWidth: 20,
  },
}

// Compact toolbar for question labels
const QUESTION_MODULES = {
  toolbar: {
    container: [
      [{ font: Font.whitelist }, { size: Size.whitelist }],
      ['bold', 'italic', 'underline', 'strike'],
      [{ color: [] }, { background: [] }],
      ['code-block', 'blockquote'],
      [{ list: 'ordered' }, { list: 'bullet' }],
      ['link', 'image', 'audio'],
      ['clean'],
    ],
    handlers: {
      audio: function () {
        const quill = this.quill
        const url = prompt('Masukkan URL audio (mp3, ogg, wav):')
        if (!url || !url.trim()) return
        const range = quill.getSelection(true)
        quill.insertEmbed(range.index, 'audio', url.trim(), 'user')
        quill.setSelection(range.index + 1, 0)
      },
    },
  },
  syntax: { hljs },
  imageResize: {
    modules: ['Resize', 'DisplaySize'],
    minWidth: 20,
  },
}

const FORMATS = [
  'font', 'size', 'header',
  'bold', 'italic', 'underline', 'strike',
  'color', 'background',
  'script',
  'blockquote', 'code-block',
  'list', 'indent', 'direction', 'align',
  'link', 'image', 'video', 'formula',
  'audio',
]

/**
 * Reusable Rich Text Editor component.
 * @param {object} props
 * @param {string} props.value - Current HTML value
 * @param {function} props.onChange - Callback when value changes
 * @param {string} [props.placeholder] - Placeholder text
 * @param {string} [props.className] - Extra CSS class
 * @param {'full'|'compact'} [props.variant] - Toolbar variant: 'full' (description) or 'compact' (question)
 */
const RichTextEditor = ({ value, onChange, placeholder, className, variant = 'full' }) => {
  const quillRef = useRef(null)
  const modules = variant === 'compact' ? QUESTION_MODULES : FULL_MODULES

  // Inject audio button icon into toolbar after mount
  useEffect(() => {
    const editor = quillRef.current
    if (!editor) return
    const toolbarEl = editor.getEditor().getModule('toolbar').container
    const audioBtns = toolbarEl.querySelectorAll('.ql-audio')
    audioBtns.forEach((btn) => {
      if (!btn.innerHTML.trim()) {
        btn.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6z"/></svg>`
        btn.title = 'Sisipkan Audio'
      }
    })
  }, [])

  return (
    <ReactQuill
      ref={quillRef}
      theme="snow"
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      modules={modules}
      formats={FORMATS}
      className={className}
    />
  )
}

export default RichTextEditor
