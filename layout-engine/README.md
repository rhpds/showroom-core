# Showroom layout engine

The layout engine allows users to configure via yaml a layout of iframes using columns, tabs and stacks.

## Configuration

* `layout` is the top level key for the configuration
* columns are defined by `left` and `right` keys in the `layout` map
  * you must add both keys to use a split column layout
  * columns require either a `url`, `tabs` or `stack` key
  * column widths can be set with the `width` key.  default is `50` (50%).
* `tabs` can be defined on both columns
  *  you can add as many tab definitions to the tabs array as required.
  * tab elements require a `name` and `url`
* `stack` supports double and triple stacks
  * `top` and `bottom` are always required and `middle` can be used to create a triple stack
  * stacks can be used in the `left` and `right` columns or any tab definition
  * `url` is required for each stack element (`left`, `middle` and `bottom`)
  * stack heights can be set with the `height` key.  default is `50` for 2 rows, `33` for 3 rows.

***Note: This is a POC, yaml configration is likely to change*** 

## Examples

### Single page

```
layout:
  url: https://www.lipsum.com
```

### 2 columns

`left` and `right` must be set
`width` of the columns can be set as a percentage.  Default is 50%. 

```
layout:
  columns:
    left:
      url: https://www.lipsum.com
      width: 50
    right:
      url: https://www.wikipedia.org
      width: 50
```

### 2 columns, tabs on right column

`name` is required and sets the tab header.

```
layout:
  columns:
    left:
      url: https://www.lipsum.com
    right:
      tabs:
      - name: Tab 1
        url: https://www.wikipedia.org
      - name: Tab 2
        url: https://www.example.com
```

### 2 columns, stacked right column

#### Double stack
* `top` and `bottom` must be set
* `height` of the stacked rows can be set as a percentage.  Default is 50% for a double stack.

```
layout:
  columns:
    left:
      url: https://www.lipsum.com
    right:
      stack:
        top:
          url: https://www.example.com
          height: 75
        bottom:
          url: https://picsum.photos/1200/1200
          height: 25
```

#### Triple stack
* `top`, `middle` and `bottom` must be set
* Default `hieght` is 33% for a triple stack.
```
layout:
  columns:
    left:
      url: https://www.lipsum.com
    right:
      stack:
        top:
          url: https://www.example.com
        middle:
          url: https://www.wikipedia.org
        bottom:
          url: https://picsum.photos/1200/1200
```

### Tabs on left and right, stacked rows in tabs

```
layout:
  columns:
    left:
      tabs:
      - name: Triple stack
        stack:
          top:
            url: https://picsum.photos/1200/1200
            height: 30
          middle:
            url: https://www.wikipedia.org
            height: 30
          bottom:
            url: https://www.example.com
            height: 40
      - name: Wikipedia
        url: https://www.wikipedia.org
    right:
      tabs:
      - name: Tab 1 | Double stack
        stack:
          top:
            url: https://www.example.com
            height: 50
          bottom:
            url: https://picsum.photos/1200/1200
            height: 50
      - name: Triple stack with default heights
        stack:
          top:
            url: https://www.example.com
          middle:
            url: https://www.wikipedia.org
          bottom:
            url: https://picsum.photos/1200/1200
```

## Development

The development environment uses podman compose and a flask development docker image.  Saving any `.py` file will auto reload the application, but modifying html templates/yaml configuration files may not.  You can define extra files to auto reload when changed via `--extra-files=templates/index.html:templates/common.html:config/2-column.yaml` in the Dockerfile.  The template html files and 2-column.yaml config is set by default here.

### Build

```
podman compose build
```

### Run
```
podman compose up
```

Navigate to `http://localhost:5000/showroom`

# TODO

* YAML configuration validation (JSON Schema)
  * Display validation errors on web for developer, also log to stderr
* How many tabs is too many tabs? Should we limit this?
* Configurable path, currently defaults to `/showroom`.  Should serve on `/` by default or pass env path `PATH=/showroom` etc to change it. 
* Production build image, currently using flask in development mode
* Add `type` key to set iframe attributes for a known type of service. ie. code-browser
* Add `attributes` key to allow customisation of iframe html element
  * ```
    layout:
      columns:
        left:
          url: https://www.wikipedia.org
          type: code-browser
        right:
          url: https://www.wikipedia.org
          attributes:
            title: Code browser
            sandbox: allow-same-origin allow-scripts
    ```
  * Both the left and right example here would create an html iframe element equivelent to `<iframe src="https://www.wikipedia.org" title="Code browser" sandbox="allow-same-origin allow-scripts"></iframe>`
* Rename url -> src to reflect iframe attr, don't need attributes then just set title, sandbox etc directly
  * ```
      src: https://www.wikipedia.org
      title: Code browser
      sandbox: allow-same-origin allow-scripts
    ```
* When using `width` or `height` if a value is missing for a column or row set the remainder automatically. ie. left width is set to 60, auto set right to 40.