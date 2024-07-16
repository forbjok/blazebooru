<script lang="ts">
import { defineComponent, h, type VNodeArrayChildren } from "vue";
import * as P from "parsimmon";

export default defineComponent({
  props: {
    text: String,
  },
  emits: ["clickquotelink"],
  setup(props, ctx) {
    return () => {
      if (!props.text) {
        return;
      }

      const rootNodes: VNodeArrayChildren = [];
      let spoilerNodes: VNodeArrayChildren = [];

      let nodes = rootNodes;
      let text = "";
      let inSpoiler = false;

      const addText = (_text: string) => {
        text += _text;
      };

      const flushText = () => {
        if (text.length > 0) {
          nodes.push(h("span", {}, text));
          text = "";
        }
      };

      const addQuote = (text: string) => {
        flushText();
        nodes.push(h("span", { class: "quote" }, text));
      };

      const addQuoteLink = (text: string) => {
        flushText();
        nodes.push(
          h(
            "a",
            {
              class: "quotelink",
              href: `#p${text.substring(2)}`,
              onClick: () => {
                ctx.emit("clickquotelink", parseInt(text.substring(2)));
              },
            },
            text,
          ),
        );
      };

      const addLink = (text: string) => {
        flushText();
        nodes.push(h("a", { href: text }, text));
      };

      const beginSpoiler = () => {
        flushText();
        nodes = spoilerNodes;
        inSpoiler = true;
      };

      const endSpoiler = () => {
        if (!inSpoiler) {
          return;
        }

        flushText();
        rootNodes.push(h("s", {}, spoilerNodes));
        spoilerNodes = [];
        nodes = rootNodes;
        inSpoiler = false;
      };

      const addNewLine = () => {
        flushText();
        nodes.push(h("br"));
      };

      const commentParser = P.createLanguage({
        comment: (r) =>
          P.alt(r.spoilerOpen, r.spoilerClose, r.quotelink, r.quote, r.link, r.text, r.newline, r.whitespace).many(),
        spoilerOpen: () => P.string("[spoiler]").map(beginSpoiler),
        spoilerClose: () => P.string("[/spoiler]").map(endSpoiler),
        quotelink: () => P.regexp(/>>(\d+)/).map(addQuoteLink),
        quote: () => P.regexp(/>([^\n]+)/).map(addQuote),
        link: () => P.regexp(/(https?:\/\/[^\s]*)/).map(addLink),
        text: () => P.regexp(/[^\s]+?/).map(addText),
        newline: () => P.regexp(/\n/).map(addNewLine),
        whitespace: () => P.regexp(/[^\S\n]+/).map(addText),
      });

      try {
        commentParser.comment.tryParse(props.text);

        flushText();
        endSpoiler();
      } catch {
        // Fall back to including the comment in plain text
        // if parsing fails.
        nodes = [props.text];
      }

      return h("div", { class: "comment-text" }, rootNodes);
    };
  },
});
</script>

<style scoped lang="scss">
.comment-text {
  word-wrap: break-word;

  s {
    background-color: var(--color-spoiler-background);
    color: var(--color-spoiler);
    text-decoration: none;

    &:hover {
      color: var(--color-spoiler-hover);
    }
  }

  .quote {
    color: var(--color-quote);
  }

  .quotelink {
    cursor: pointer;
  }
}
</style>
