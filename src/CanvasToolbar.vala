/*
* Copyright (c) 2020-2021 (https://github.com/phase1geo/Annotator)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;
using Gee;

public class CanvasToolbar : Box {

  private const int margin = 5;

  private Canvas             _canvas;
  private ToggleButton       _crop_btn;
  private Array<CheckButton> _width_btns;
  private Array<CheckButton> _dash_btns;
  private ColorChooserWidget _color_chooser;
  private Switch             _asw;
  private Revealer           _areveal;
  private Scale              _ascale;
  private FontChooserWidget  _font_chooser;
  private int                _current_shape;
  private HashMap<CanvasItemCategory,CurrentItem> _current_item;

  /* Constructor */
  public CanvasToolbar( Canvas canvas ) {

    _canvas       = canvas;
    _width_btns   = new Array<CheckButton>();
    _dash_btns    = new Array<CheckButton>();
    _current_item = new HashMap<CanvasItemCategory,CurrentItem>();

    /* Create current items */
    _current_item.set( CanvasItemCategory.ARROW, new CurrentItem.with_canvas_item( CanvasItemType.ARROW ) );
    _current_item.set( CanvasItemCategory.SHAPE, new CurrentItem.with_canvas_item( CanvasItemType.RECT_STROKE ) );

    create_shapes( CanvasItemCategory.ARROW, _( "Add Arrow" ), _( "More Arrows" ), _( "Custom Arrows" ) );
    create_shapes( CanvasItemCategory.SHAPE, _( "Add Shape" ), _( "More Shapes" ), _( "Custom Shapes" ) );
    create_sticker();
    create_sequence();
    create_pencil();
    create_text();
    create_magnifier();
    create_blur();
    create_separator();
    create_crop();
    create_resize();
    create_separator();
    create_color();
    create_stroke();
    create_fonts();

    /* If the selection changes, update the toolbar */
    _canvas.items.selection_changed.connect( selection_changed );

  }

  /* Creates the shape toolbar item */
  private void create_shapes( CanvasItemCategory category, string tooltip, string mb_tooltip, string custom_label ) {

    var box = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };

    var fb = new FlowBox() {
      orientation = Orientation.HORIZONTAL,
      min_children_per_line = 4,
      max_children_per_line = 4
    };

    var mb = new MenuButton() {
      // label        = "\u25bc",
      has_frame    = false,
      margin_start = 0,
      margin_end   = margin,
      tooltip_text = mb_tooltip,
      popover      = new Popover()
    };

    var btn = new Button() {
      has_frame    = false,
      margin_start = margin,
      margin_end   = 0,
      tooltip_text = tooltip,
      child        = _current_item.get( category ).get_image()
    };
    btn.clicked.connect(() => {
      _current_item.get( category ).add_item( _canvas.items );
    });

    for( int i=0; i<CanvasItemType.NUM; i++ ) {
      var shape_type = (CanvasItemType)i;
      if( shape_type.category() == category ) {
        var b = new Button() {
          icon_name     = shape_type.icon_name(),
          has_frame     = false,
          margin_start  = 5,
          margin_end    = 5,
          margin_top    = 5,
          margin_bottom = 5,
          tooltip_markup = shape_type.tooltip(),
        };
        b.clicked.connect(() => {
          _current_item.get( category ).canvas_item( shape_type );
          _current_item.get( category ).add_item( _canvas.items );
          btn.child = _current_item.get( category ).get_image();
          mb.popover.popdown();
        });
        fb.append( b );
      }
    }

    box.append( fb );
    _canvas.items.custom_items.create_menu( category, mb.popover, box, custom_label, 4 );
    _canvas.items.custom_items.item_selected.connect((cat, item) => {
      if( cat == category ) {
        _current_item.get( cat ).custom_item( item );
        _current_item.get( cat ).add_item( _canvas.items );
        btn.child = _current_item.get( cat ).get_image();
        mb.popover.popdown();
      }
    });

    mb.popover.child = box;

    append( btn );
    append( mb );

    /* If the system dark mode changes, hide the popover */
    var granite_settings = Granite.Settings.get_default();
    granite_settings.notify["prefers-color-scheme"].connect (() => {
      mb.popover.hide();
    });

  }

  /* Creates the sticker toolbar item */
  private void create_sticker() {

    var mb = new MenuButton() {
      icon_name = "sticker-symbolic",
      tooltip_markup = CanvasItemType.STICKER.tooltip(),
      has_frame = false,
      popover = new Popover()
    };

    var box = new Box( Orientation.VERTICAL, 0 );
    var vp  = new Viewport( null, null ) {
      child = box
    };
    vp.set_size_request( 200, 400 );
    var sw  = new ScrolledWindow() {
      child = vp
    };

    create_via_xml( box, mb.popover );

    mb.popover.child = sw;

    /*
    var btn = new Button() {
      margin_start = margin,
      margin_end   = margin,
      child        = mb
    };
    */

    append( mb );

  }

  /* Creates the rest of the UI from the stickers XML file that is stored in a gresource */
  private void create_via_xml( Box box, Popover popover ) {

    try {
      var template = resources_lookup_data( "/com/github/phase1geo/annotator/images/stickers.xml", ResourceLookupFlags.NONE);
      var contents = (string)template.get_data();
      Xml.Doc* doc = Xml.Parser.parse_memory( contents, contents.length );
      if( doc != null ) {
        for( Xml.Node* it=doc->get_root_element()->children; it!=null; it=it->next ) {
          if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "category") ) {
            var category = create_category( box, it->get_prop( "name" ) );
            for( Xml.Node* it2=it->children; it2!=null; it2=it2->next ) {
              if( (it2->type == Xml.ElementType.ELEMENT_NODE) && (it2->name == "img") ) {
                var name = it2->get_prop( "title" );
                create_image( category, name, popover );
              }
            }
          }
        }
        delete doc;
      }
    } catch( Error e ) {
      warning( "Failed to load sticker XML template: %s", e.message );
    }

  }

  /* Creates the expander flowbox for the given category name and adds it to the sidebar */
  private FlowBox create_category( Box box, string name ) {

    /* Create the flowbox which will contain the stickers */
    var fbox = new FlowBox() {
      homogeneous = true,
      selection_mode = SelectionMode.NONE
    };

    /* Create expander */
    var exp = new Expander( Utils.make_title( name ) ) {
      margin_start = 20,
      margin_end   = 20,
      use_markup   = true,
      expanded     = true,
      child        = fbox
    };

    box.append( exp );

    return( fbox );

  }

  /* Creates the image from the given name and adds it to the flow box */
  private void create_image( FlowBox box, string name, Popover popover ) {

    var resource = "/com/github/phase1geo/annotator/images/sticker_%s".printf( name );

    var btn = new Button() {
      has_frame    = false,
      tooltip_text = name,
      child        = new Image.from_resource( resource )
    };
    btn.clicked.connect((e) => {
      _canvas.items.add_sticker( resource );
      popover.popdown();
    });

    box.append( btn );

  }

  /* Adds the sequence button */
  private void create_sequence() {

    var btn = new Button.from_icon_name( "sequence-symbolic" ) {
      tooltip_markup = CanvasItemType.SEQUENCE.tooltip(),
      margin_start   = margin,
      margin_end     = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.add_shape_item( CanvasItemType.SEQUENCE );
    });

    append( btn );

  }

  /* Starts a drawing operation with the pencil tool */
  private void create_pencil() {

    var btn = new Button.from_icon_name( "edit-symbolic" ) {
      tooltip_markup = CanvasItemType.PENCIL.tooltip(),
      margin_start   = margin,
      margin_end     = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.add_shape_item( CanvasItemType.PENCIL );
    });

    append( btn );

  }

  /* Adds the text insertion button */
  private void create_text() {

    var btn = new Button.from_icon_name( "insert-text-symbolic" ) {
      tooltip_markup = CanvasItemType.TEXT.tooltip(),
      margin_start   = margin,
      margin_end     = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.add_shape_item( CanvasItemType.TEXT );
    });

    append( btn );

  }

  private void create_magnifier() {

    var btn = new Button.from_icon_name( "magnifier-symbolic" ) {
      tooltip_markup = CanvasItemType.MAGNIFIER.tooltip(),
      margin_start   = margin,
      margin_end     = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.add_shape_item( CanvasItemType.MAGNIFIER );
    });

    append( btn );

  }

  /* Create the blur button */
  private void create_blur() {

    var btn = new Button.from_icon_name( "blur-symbolic" ) {
      tooltip_markup = CanvasItemType.BLUR.tooltip(),
      margin_start   = margin,
      margin_end     = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.add_shape_item( CanvasItemType.BLUR );
    });

    append( btn );

  }

  /* Create the crop button */
  private void create_crop() {

    _crop_btn = new ToggleButton() {
      has_frame    = false,
      tooltip_text = _( "Crop Image" ),
      icon_name    = "image-crop-symbolic",
      margin_start = margin,
      margin_end   = margin
    };
    _crop_btn.toggled.connect(() => {
      if( !_crop_btn.active ) {
        _canvas.image.cancel_crop();
      } else {
        _canvas.items.clear_selection();
        _canvas.image.start_crop();
      }
      _canvas.items.clear_selection();
      _canvas.queue_draw();
      _canvas.grab_focus();
    });

    append( _crop_btn );

  }

  /* Create the image resizer button */
  private void create_resize() {

    var btn = new Button.from_icon_name( "view-fullscreen-symbolic" ) {
      tooltip_text = _( "Resize Image" ),
      margin_start = margin,
      margin_end   = margin
    };
    btn.clicked.connect(() => {
      _canvas.items.clear_selection();
      _canvas.image.resize_image();
      _canvas.queue_draw();
      _canvas.grab_focus();
    });

    append( btn );

  }

  /* Creates the color dropdown */
  private void create_color() {

    var mb = new MenuButton() {
      has_frame    = false,
      tooltip_text = _( "Shape Color" ),
      popover      = new Popover(),
      child        = make_color_icon()
    };
    mb.get_style_context().add_class( "color_chooser" );

    var box = new Box( Orientation.VERTICAL, 0 ) {
      margin_start  = 10,
      margin_end    = 10,
      margin_top    = 10,
      margin_bottom = 10
    };

    _color_chooser = new ColorChooserWidget() {
      rgba = _canvas.items.props.color
    };
    _color_chooser.notify.connect((p) => {
      _canvas.items.props.color = _color_chooser.rgba;
      mb.child = make_color_icon();
    });
    box.append( _color_chooser );

    create_color_alpha( mb, box );

    mb.popover.child = box;

    append( mb );

  }

  private void create_color_alpha( MenuButton mb, Box box ) {

    _ascale = new Scale.with_range( Orientation.HORIZONTAL, 0.0, 1.0, 0.1 ) {
      margin_start = 20,
      margin_end   = 20,
      draw_value   = true
    };
    _ascale.set_value( _canvas.items.props.alpha );
    _ascale.value_changed.connect(() => {
      _canvas.items.props.alpha = _ascale.get_value();
      mb.child = make_color_icon();
    });
    for( int i=0; i<=10; i++ ) {
      _ascale.add_mark( (i / 10.0), PositionType.BOTTOM, null );
    }

    _areveal = new Revealer() {
      reveal_child = (_canvas.items.props.alpha < 1.0),
      child = _ascale
    };

    var btn_controller = new GestureClick();
    _asw = new Switch() {
      halign = Align.START,
      active = (_canvas.items.props.alpha < 1.0)
    };
    _asw.add_controller( btn_controller );
    btn_controller.released.connect((n_press, x, y) => {
      _canvas.items.props.alpha = _areveal.reveal_child ? 1.0 : _ascale.get_value();
      mb.child = make_color_icon();
      _areveal.reveal_child = !_areveal.reveal_child;
    });

    var albl = new Label( Utils.make_title( _( "Add Transparency" ) ) ) {
      halign     = Align.START,
      use_markup = true,
      margin_end = 10
    };

    var albox = new Box( Orientation.HORIZONTAL, 10 ) {
      halign = Align.FILL,
      hexpand = true
    };
    albox.append( _asw );
    albox.append( albl );

    var abox = new Box( Orientation.VERTICAL, 0 ) {
      halign = Align.FILL,
      hexpand = true,
      margin_top = 20
    };
    abox.append( albox );
    abox.append( _areveal );

    box.append( abox );

  }

  /* Adds the stroke dropdown */
  private void create_stroke() {

    var mb = new MenuButton() {
      has_frame    = false,
      tooltip_text = _( "Shape Border" ),
      popover      = new Gtk.Popover(),
      child        = make_stroke_icon()
    };

    var box = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 10,
      margin_end    = 10,
      margin_top    = 10,
      margin_bottom = 10
    };

    /* Add stroke width */
    var width_title = new Label( Utils.make_title( _( "Border Width" ) ) ) {
      halign     = Align.START,
      use_markup = true
    };
    box.append( width_title );

    unowned CheckButton? width_group = null;
    for( int i=0; i<CanvasItemStrokeWidth.NUM; i++ ) {
      var sw  = (CanvasItemStrokeWidth)i;
      // var btn = new CheckButton() {
      var btn = new CheckButton.with_label( sw.to_string() ) {
        margin_start = 20,
        active       = (_canvas.items.props.stroke_width == sw),
// TODO        child        = make_width_icon( 100, sw.width() )
      };
      btn.set_group( width_group );
      btn.toggled.connect(() => {
        if( btn.get_active() ) {
          _canvas.items.props.stroke_width = sw;
          mb.child = make_stroke_icon();
        }
      });
      _width_btns.append_val( btn );
      if( width_group == null ) {
        width_group = btn;
      }
      box.append( btn );
    }

    /* Add dash patterns */
    var dash_title = new Label( Utils.make_title( _( "Dash Pattern" ) ) ) {
      halign     = Align.START,
      margin_top = 20,
      use_markup = true
    };
    box.append( dash_title );

    unowned CheckButton? dash_group = null;
    for( int i=0; i<CanvasItemDashPattern.NUM; i++ ) {
      var dash = (CanvasItemDashPattern)i;
      // var btn  = new CheckButton() {
      var btn  = new CheckButton.with_label( dash.to_string() ) {
        margin_start = 20,
        active       = (_canvas.items.props.dash == dash),
// TODO        child        = make_dash_icon( 100, dash )
      };
      btn.set_group( dash_group );
      btn.toggled.connect(() => {
        if( btn.get_active() ) {
          _canvas.items.props.dash = dash;
          mb.child = make_stroke_icon();
        }
      });
      _dash_btns.append_val( btn );
      if( dash_group == null ) {
        dash_group = btn;
      }
      box.append( btn );
    }

    /* Add outline */
    var outline_title = new Label( Utils.make_title( _( "Show Outline" ) ) ) {
      halign     = Align.START,
      use_markup = true
    };
    var outline_sw = new Switch() {
      halign = Align.END,
      active = _canvas.items.props.outline
    };
    outline_sw.activate.connect((e) => {
      _canvas.items.props.outline = !_canvas.items.props.outline;
    });
    var outline_box = new Box( Orientation.HORIZONTAL, 10 ) {
      homogeneous = false,
      margin_top  = 20
    };
    outline_box.append( outline_title );
    outline_box.append( outline_sw );
    box.append( outline_box );

    mb.popover.child = box;

    append( mb );

  }

  /* Adds the font menubutton */
  private void create_fonts() {

    var mb = new MenuButton() {
      icon_name    = "font-x-generic-symbolic",
      tooltip_text = _( "Font Properties" ),
      has_frame    = false,
      popover      = new Popover()
    };
    mb.get_style_context().add_class( "color_chooser" );

    _font_chooser = new FontChooserWidget() {
      margin_start  = 10,
      margin_end    = 10,
      margin_top    = 10,
      margin_bottom = 10,
      font_desc     = _canvas.items.props.font
    };
    _font_chooser.set_filter_func( (family, face) => {
      var fd     = face.describe();
      var weight = fd.get_weight();
      var style  = fd.get_style();
      return( (weight == Pango.Weight.NORMAL) && (style == Pango.Style.NORMAL) );
    });
    _font_chooser.notify.connect((p) => {
      if( p.name == "font" ) {
        _canvas.items.props.font = Pango.FontDescription.from_string( _font_chooser.get_font() );
      }
    });

    mb.popover.child = _font_chooser;

    append( mb );

  }

  private Image make_color_icon() {

    var snapshot = new Snapshot();
    var rect     = Graphene.Rect.alloc();
    rect.init( 0, 0, (float)30, (float)24 );
    var ctx      = snapshot.append_cairo( rect );

    /* Draw the image */
    var stroke = Granite.contrasting_foreground_color( _canvas.items.props.color );
    Utils.set_context_color_with_alpha( ctx, _canvas.items.props.color, _canvas.items.props.alpha );
    ctx.rectangle( 0, 0, 30, 24 );
    ctx.fill_preserve();

    Utils.set_context_color_with_alpha( ctx, stroke, 0.5 );
    ctx.stroke();

    var image = new Image.from_paintable( snapshot.free_to_paintable( null ) );

    return( image );

  }

  /* Returns true if the current mode is dark mode */
  private bool is_dark_mode() {

    var settings = Gtk.Settings.get_default();
    if( settings != null ) {
      return( settings.gtk_application_prefer_dark_theme );
    }

    return( false );

  }

  private Image make_width_icon( int width, int stroke_width ) {

    var height = stroke_width;

    var snapshot = new Snapshot();
    var rect     = Graphene.Rect.alloc();
    rect.init( 0, 0, (float)width, (float)height );
    var ctx      = snapshot.append_cairo( rect );

    /* Draw the stroke */
    Utils.set_context_color( ctx, Utils.color_from_string( is_dark_mode() ? "white" : "black" ) );
    ctx.set_line_width( stroke_width );
    ctx.move_to( 0, (height / 2) );
    ctx.line_to( width, (height / 2) );
    ctx.stroke();

    var image = new Image.from_paintable( snapshot.free_to_paintable( null ) );

    return( image );

  }

  private Image make_dash_icon( int width, CanvasItemDashPattern dash ) {

    var height = 5;

    var snapshot = new Snapshot();
    var rect     = Graphene.Rect.alloc();
    rect.init( 0, 0, (float)width, (float)height );
    var ctx      = snapshot.append_cairo( rect );

    /* Draw the image */
    Utils.set_context_color( ctx, Utils.color_from_string( is_dark_mode() ? "white" : "black" ) );
    ctx.set_line_width( height );
    dash.set_fg_pattern( ctx );
    ctx.move_to( 0, (height / 2) );
    ctx.line_to( width, (height / 2) );
    ctx.stroke();

    var image = new Image.from_paintable( snapshot.free_to_paintable( null ) );

    return( image );

  }

  private Image make_stroke_icon() {

    var width   = 50;
    var height  = _canvas.items.props.stroke_width.width();

    var snapshot = new Snapshot();
    var rect     = Graphene.Rect.alloc();
    rect.init( 0, 0, (float)50, (float)height );
    var ctx      = snapshot.append_cairo( rect );

    /* Draw the image */
    Utils.set_context_color( ctx, Utils.color_from_string( is_dark_mode() ? "white" : "black" ) );
    ctx.set_line_width( height );
    _canvas.items.props.dash.set_fg_pattern( ctx );
    ctx.move_to( 0, (height / 2) );
    ctx.line_to( width, (height / 2) );
    ctx.stroke();

    var image = new Image.from_paintable( snapshot.free_to_paintable( null ) );

    return( image );

  }

  /* Adds a separator to the toolbar */
  private void create_separator() {

    var sep = new Separator( Orientation.VERTICAL );

    append( sep );

  }

  /* Called when the canvas image crop ends */
  public void crop_ended() {
    _crop_btn.active = false;
  }

  /* Called whenever the item selection changes */
  private void selection_changed( CanvasItemProperties props ) {

    var p = new CanvasItemProperties();
    p.copy( props );

    /* Updates the width group */
    _width_btns.index( (int)p.stroke_width ).set_active( true );

    /* Updates the dash group */
    _dash_btns.index( (int)p.dash ).set_active( true );

    /* Set the color */
    _color_chooser.rgba = p.color;

    /* Handle the alpha value */
    _ascale.set_value( p.alpha );
    _areveal.reveal_child = (p.alpha < 1.0);
    _asw.set_active( p.alpha < 1.0 );

    /* Set the font */
    _font_chooser.font_desc = p.font;

  }

  /*
   Displays the custom menu for the specified item category type
   relative to the given widget.
  */
  /*
  private void show_custom_menu( Widget w, CanvasItemCategory category ) {

    var fb = new FlowBox();
    fb.orientation = Orientation.HORIZONTAL;
    fb.min_children_per_line = 4;
    fb.max_children_per_line = 4;

    var popover = new Popover( w );
    _canvas.items.custom_items.populate_menu( category, null, popover, fb );

    if( fb.get_children().length() > 0 ) {
      popover.add( fb );
      Utils.show_popover( popover );
    }

  }
  */

}

