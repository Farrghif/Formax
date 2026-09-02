import * as react_jsx_runtime from 'react/jsx-runtime';
import * as Quill from 'quill';
import Quill__default, { Range as Range$1, QuillOptions as QuillOptions$1, EmitterSource } from 'quill';
export { EmitterSource, default as Quill, QuillOptions as QuillOptionsStatic, Range as RangeStatic } from 'quill';
import React from 'react';
import DeltaStatic from 'quill-delta';
export { default as DeltaStatic } from 'quill-delta';

type Value = ReactQuill.Value;
type Range = ReactQuill.Range;
type QuillOptions = ReactQuill.QuillOptions;
type ReactQuillProps = ReactQuill.ReactQuillProps;
type UnprivilegedEditor = ReactQuill.UnprivilegedEditor;
interface ReactQuillState {
    generation: number;
}
declare namespace ReactQuill {
    type Value = string | DeltaStatic;
    type Range = Range$1 | null;
    interface QuillOptions extends QuillOptions$1 {
        tabIndex?: number;
    }
    interface ReactQuillProps {
        bounds?: string | HTMLElement;
        children?: React.ReactElement<any>;
        className?: string;
        defaultValue?: Value;
        formats?: string[];
        id?: string;
        modules?: QuillOptions['modules'];
        onChange?(value: string, delta: DeltaStatic, source: EmitterSource, editor: UnprivilegedEditor): void;
        onChangeSelection?(selection: Range, source: EmitterSource, editor: UnprivilegedEditor): void;
        onFocus?(selection: Range, source: EmitterSource, editor: UnprivilegedEditor): void;
        onBlur?(previousSelection: Range, source: EmitterSource, editor: UnprivilegedEditor): void;
        onKeyDown?: React.EventHandler<any>;
        onKeyPress?: React.EventHandler<any>;
        onKeyUp?: React.EventHandler<any>;
        placeholder?: string;
        preserveWhitespace?: boolean;
        readOnly?: boolean;
        style?: React.CSSProperties;
        tabIndex?: number;
        theme?: string;
        value?: Value;
        /**
         * If false, uses editor.root.innerHTML instead of getSemanticHTML().
         * This preserves non-semantic elements like <style> tags.
         * @default true
         */
        useSemanticHTML?: boolean;
    }
    interface UnprivilegedEditor {
        getLength: Quill__default['getLength'];
        getText: Quill__default['getText'];
        getHTML: () => string;
        getSemanticHTML: Quill__default['getSemanticHTML'];
        getBounds: Quill__default['getBounds'];
        getSelection: Quill__default['getSelection'];
        getContents: Quill__default['getContents'];
    }
}
declare class ReactQuill extends React.Component<ReactQuillProps, ReactQuillState> {
    editingAreaRef: React.RefObject<any>;
    containerRef: React.RefObject<any>;
    static displayName: string;
    static Quill: typeof Quill__default;
    dirtyProps: (keyof ReactQuillProps)[];
    cleanProps: (keyof ReactQuillProps)[];
    static defaultProps: {
        theme: string;
        modules: {};
        readOnly: boolean;
    };
    state: ReactQuillState;
    editor?: Quill__default;
    value: Value;
    selection: Range;
    lastDeltaChangeSet?: DeltaStatic;
    regenerationSnapshot?: {
        delta: DeltaStatic;
        selection: Range;
    };
    unprivilegedEditor?: UnprivilegedEditor;
    constructor(props: ReactQuillProps);
    validateProps(props: ReactQuillProps): void;
    shouldComponentUpdate(nextProps: ReactQuillProps, nextState: ReactQuillState): boolean;
    shouldComponentRegenerate(nextProps: ReactQuillProps): boolean;
    componentDidMount(): void;
    componentWillUnmount(): void;
    componentDidUpdate(prevProps: ReactQuillProps, prevState: ReactQuillState): void;
    instantiateEditor(): void;
    destroyEditor(): void;
    isControlled(): boolean;
    getEditorConfig(): QuillOptions;
    getEditor(): Quill__default;
    /**
    Creates an editor on the given element. The editor will be passed the
    configuration, have its events bound,
    */
    createEditor(element: HTMLElement, config: QuillOptions): Quill__default;
    hookEditor(editor: Quill__default): void;
    unhookEditor(editor: Quill__default): void;
    getEditorContents(): Value;
    getEditorSelection(): Range;
    isDelta(value: any): boolean;
    isEqualValue(value: any, nextValue: any): boolean;
    setEditorContents(editor: Quill__default, value: Value): void;
    setEditorSelection(editor: Quill__default, range: Range): void;
    setEditorTabIndex(editor: Quill__default, tabIndex: number): void;
    setEditorReadOnly(editor: Quill__default, value: boolean): void;
    makeUnprivilegedEditor(editor: Quill__default): {
        getHTML: () => string;
        getSemanticHTML: {
            (range: Range$1): string;
            (index?: number, length?: number): string;
        };
        getLength: () => number;
        getText: {
            (range?: Range$1): string;
            (index?: number, length?: number): string;
        };
        getContents: (index?: number, length?: number) => DeltaStatic;
        getSelection: {
            (focus: true): Range$1;
            (focus?: boolean): Range$1 | null;
        };
        getBounds: (index: number | Range$1, length?: number) => Quill.Bounds | null;
    };
    getEditingArea(): HTMLElement;
    renderEditingArea(): JSX.Element;
    render(): react_jsx_runtime.JSX.Element;
    onEditorChange: (eventName: "text-change" | "selection-change", rangeOrDelta: Range | DeltaStatic, oldRangeOrDelta: Range | DeltaStatic, source: EmitterSource) => void;
    onEditorChangeText(value: string, delta: DeltaStatic, source: EmitterSource, editor: UnprivilegedEditor): void;
    onEditorChangeSelection(nextSelection: Range$1, source: EmitterSource, editor: UnprivilegedEditor): void;
    focus(): void;
    blur(): void;
}

export { ReactQuill as default };
