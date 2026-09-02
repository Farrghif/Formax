import { useRef, useEffect } from 'react'
import ReactQuill, { Quill } from 'react-quill-new'
import 'react-quill-new/dist/quill.snow.css'
import { uploadFile } from '../api/uploads'
import { apiFetch } from '../api/config'
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

// ── Custom Image Blot ────────────────────────────────────────────────────────
const ImageBlot = Quill.import('formats/image')
class CustomImageBlot extends ImageBlot {
  static value(node) {
    // Preserve originalSrc if ngrok blob patch was applied
    return node.dataset?.originalSrc || node.getAttribute('src')
  }
}
Quill.register(CustomImageBlot, true)
// ─────────────────────────────────────────────────────────────────────────────

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
    // Fix hilang setelah Simpan: jika src sudah jadi blob:URL karena ngrok patch,
    // kembalikan originalSrc agar yang tersimpan di DB tetap ngrok URL
    return node.dataset?.originalSrc || node.getAttribute('src')
  }
}
AudioBlot.blotName = 'audio'
AudioBlot.tagName = 'audio'
Quill.register(AudioBlot)
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom Image Upload Handler ──────────────────────────────────────────────
const handleImageUpload = function () {
  const quill = this.quill
  const input = document.createElement('input')
  input.setAttribute('type', 'file')
  input.setAttribute('accept', 'image/*')
  input.click()

  input.onchange = async () => {
    const file = input.files[0]
    if (!file) return

    const token = localStorage.getItem('token')
    const range = quill.getSelection(true)
    const index = range ? range.index : (quill.getLength() || 0)

    try {
      const result = await uploadFile(token, file)
      const url = result?.file_url
      if (url) {
        quill.insertEmbed(index, 'image', url, 'user')
        quill.setSelection(index + 1, 0)
      } else {
        alert('Gagal mengunggah gambar: URL file tidak ditemukan dalam respons server.')
      }
    } catch (err) {
      alert('Gagal mengunggah gambar: ' + err.message)
    }
  }
}
// ─────────────────────────────────────────────────────────────────────────────

// ── Custom Audio Upload Handler ──────────────────────────────────────────────
const handleAudioUpload = function () {
  const quill = this.quill
  const input = document.createElement('input')
  input.setAttribute('type', 'file')
  input.setAttribute('accept', 'audio/*')
  input.click()

  input.onchange = async () => {
    const file = input.files[0]
    if (!file) return

    const token = localStorage.getItem('token')
    const range = quill.getSelection(true)
    const index = range ? range.index : (quill.getLength() || 0)

    try {
      const result = await uploadFile(token, file)
      const url = result?.file_url
      if (url) {
        quill.insertEmbed(index, 'audio', url, 'user')
        quill.setSelection(index + 1, 0)
      } else {
        alert('Gagal mengunggah audio: URL file tidak ditemukan dalam respons server.')
      }
    } catch (err) {
      alert('Gagal mengunggah audio: ' + err.message)
    }
  }
}
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
      image: handleImageUpload,
      audio: handleAudioUpload,
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
      image: handleImageUpload,
      audio: handleAudioUpload,
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

  // Inject audio & image button title/icon into toolbar after mount
  useEffect(() => {
    const editor = quillRef.current
    if (!editor) return
    const toolbarEl = editor.getEditor().getModule('toolbar').container
    const audioBtns = toolbarEl.querySelectorAll('.ql-audio')
    audioBtns.forEach((btn) => {
      if (!btn.innerHTML.trim()) {
        btn.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6z"/></svg>`
      }
      btn.title = 'Sisipkan Audio'
    })
    const imageBtns = toolbarEl.querySelectorAll('.ql-image')
    imageBtns.forEach((btn) => {
      btn.title = 'Sisipkan Gambar'
    })
  }, [])

  // Fix media (audio & image) ngrok di dalam editor preview (builder)
  useEffect(() => {
    const editor = quillRef.current?.getEditor()
    if (!editor || !value || !value.includes('ngrok-free')) return
    const root = editor.root
    const mediaElements = root.querySelectorAll('audio[src*="ngrok-free"], img[src*="ngrok-free"]')
    if (mediaElements.length === 0) return
    const controllers = []

    mediaElements.forEach((el) => {
      const src = el.getAttribute('src')
      if (!src || src.startsWith('data:') || src.startsWith('blob:') || el.dataset.ngrokFixed) return
      el.dataset.ngrokFixed = '1'
      el.dataset.originalSrc = src
      const controller = new AbortController()
      controllers.push(controller)
      el.style.opacity = '0.6'
      apiFetch(src, { signal: controller.signal })
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`)
          return res.blob()
        })
        .then((blob) => {
          if (blob.type && blob.type.startsWith('text/html')) throw new Error('Ngrok HTML')
          const blobUrl = URL.createObjectURL(blob)
          el.src = blobUrl
          if (el.tagName === 'AUDIO') el.load()
          el.style.opacity = '1'
          el.dataset.blobUrl = blobUrl
        })
        .catch((err) => {
          if (err.name === 'AbortError') return
          console.error('[RichTextEditor NgrokMedia] gagal:', src, err)
          el.style.opacity = '1'
        })
    })

    return () => {
      controllers.forEach((c) => c.abort())
    }
  }, [value])

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
