module.exports = function (eleventyConfig) {
  // Copy all vendored/static assets (theme CSS/JS, images, fonts, form page, etc.)
  // from /static straight to the site root, unchanged.
  eleventyConfig.addPassthroughCopy({ "static": "." });

  // Our readable, hand-editable overrides (dock, glass cards, etc.)
  eleventyConfig.addPassthroughCopy({ "src/assets": "assets" });

  return {
    dir: { input: "src", includes: "_includes", data: "_data", output: "_site" },
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
    templateFormats: ["njk", "md", "html"]
  };
};
