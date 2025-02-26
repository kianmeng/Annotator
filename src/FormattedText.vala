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

using Pango;
using Gdk;
using Gtk;
using Gee;

public enum FormatTag {
  BOLD = 0,
  ITALICS,
  UNDERLINE,
  STRIKETHRU,
  CODE,
  SUB,
  SUPER,
  HEADER,
  COLOR,
  HILITE,
  SELECT,
  LENGTH;

  public string to_string() {
    switch( this ) {
      case BOLD       :  return( "bold" );
      case ITALICS    :  return( "italics" );
      case UNDERLINE  :  return( "underline" );
      case STRIKETHRU :  return( "strikethru" );
      case CODE       :  return( "code" );
      case SUB        :  return( "subscript" );
      case SUPER      :  return( "superscript" );
      case HEADER     :  return( "header" );
      case COLOR      :  return( "color" );
      case HILITE     :  return( "hilite" );
    }
    return( "bold" );
  }

  public static FormatTag from_string( string str ) {
    switch( str ) {
      case "bold"        :  return( BOLD );
      case "italics"     :  return( ITALICS );
      case "underline"   :  return( UNDERLINE );
      case "strikethru"  :  return( STRIKETHRU );
      case "code"        :  return( CODE );
      case "subscript"   :  return( SUB );
      case "superscript" :  return( SUPER );
      case "header"      :  return( HEADER );
      case "color"       :  return( COLOR );
      case "hilite"      :  return( HILITE );
    }
    return( LENGTH );
  }

}

/* Stores information for undo/redo operation on tags */
public class UndoTagInfo {
  public int     start { private set; get; }
  public int     end   { private set; get; }
  public int     tag   { private set; get; }
  public string? extra { private set; get; }
  public UndoTagInfo( int tag, int start, int end, string? extra ) {
    this.tag   = tag;
    this.start = start;
    this.end   = end;
    this.extra = extra;
  }
  public string to_string() {
    return( "tag: %s, start: %d, end: %d, extra: %s".printf( tag.to_string(), start, end, extra ) );
  }
}


public class FormattedText {

  private class TagInfo {

    public class FormattedRange {
      public int     start { get; set; default = 0; }
      public int     end   { get; set; default = 0; }
      public string? extra { get; set; default = null; }
      public FormattedRange( int s, int e, string? x ) {
        start = s;
        end   = e;
        extra = x;
      }
      public FormattedRange.from_xml( Xml.Node* n ) {
        load( n );
      }
      public bool combine( int s, int e, string? x ) {
        bool changed = false;
        if( (x != null) && (x != extra) ) {
          return( false );
        }
        if( (s <= end) && (e > end) ) {
          end     = e;
          changed = true;
        }
        if( (s < start) && (e >= start) ) {
          start   = s;
          changed = true;
        }
        return( changed );
      }
      public Xml.Node* save() {
        Xml.Node* n = new Xml.Node( null, "range" );
        n->set_prop( "start", start.to_string() );
        n->set_prop( "end",   end.to_string() );
        if( extra != null ) {
          n->set_prop( "extra", extra );
        }
        return( n );
      }
      public void load( Xml.Node* n ) {
        string? s = n->get_prop( "start" );
        if( s != null ) {
          start = int.parse( s );
        }
        string? e = n->get_prop( "end" );
        if( e != null ) {
          end = int.parse( e );
        }
        extra = n->get_prop( "extra" );
      }
      public static int compare( void* x, void* y ) {
     		 FormattedRange** x1 = (FormattedRange**)x;
       	FormattedRange** y1 = (FormattedRange**)y;
        return( (int)((*x1)->start > (*y1)->start) - (int)((*x1)->start < (*y1)->start) );
      }
    }

    private Array<FormattedRange> _info;

    public Array<FormattedRange> info {
      get {
        return( _info );
      }
    }

    /* Default constructor */
    public TagInfo() {
      _info = new Array<FormattedRange>();
    }

    /* Copies the given TagInfo structure to this one */
    public void copy( TagInfo other ) {
      _info.remove_range( 0, _info.length );
      for( int i=0; i<other._info.length; i++ ) {
        var other_info = other._info.index( i );
        _info.append_val( new FormattedRange( other_info.start, other_info.end, other_info.extra ) );
      }
    }

    /* Returns true if this info array is empty */
    public bool is_empty() {
      return( _info.length == 0 );
    }

    public void adjust( int index, int length ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( index <= info.start ) {
          info.start += length;
          info.end   += length;
          if( info.end <= index ) {
            _info.remove_index( i );
          }
        } else if( index < info.end ) {
          info.end += length;
        }
      }
    }

    /* Adds the given range from this format type */
    public void add_tag( int start, int end, string? extra ) {
      for( int i=0; i<_info.length; i++ ) {
        if( _info.index( i ).combine( start, end, extra ) ) {
          return;
        }
      }
      _info.append_val( new FormattedRange( start, end, extra ) );
      _info.sort( (CompareFunc)FormattedRange.compare );
    }

    /* Adds the given TagInfo contents to the existing list */
    public void add_tags_at_offset( TagInfo other, int offset ) {
      for( int i=0; i<other._info.length; i++ ) {
        var other_info = other._info.index( i );
        add_tag( (other_info.start + offset), (other_info.end + offset), other_info.extra );
      }
    }

    /* Replaces the given range(s) with the given range */
    public void replace_tag( int start, int end, string? extra ) {
      _info.remove_range( 0, _info.length );
      _info.append_val( new FormattedRange( start, end, extra ) );
      _info.sort( (CompareFunc)FormattedRange.compare );
    }

    /* Removes the given range from this format type */
    public void remove_tag( int start, int end ) {
      for( int i=((int)_info.length - 1); i>=0; i-- ) {
        var info = _info.index( i );
        if( (start < info.end) && (end > info.start) ) {
          if( start <= info.start ) {
            if( info.end <= end ) {
              _info.remove_index( i );
            } else {
              info.start = end;
            }
          } else {
            if( info.end > end ) {
              _info.append_val( new FormattedRange( end, info.end, info.extra ) );
            }
            info.end = start;
          }
        }
      }
      _info.sort( (CompareFunc)FormattedRange.compare );
    }

    /* Removes all ranges for this tag */
    public void remove_tag_all() {
      _info.remove_range( 0, _info.length );
    }

    /*
     Returns true if the text contains a tag that matches the given extra information.
     If extra is set to the empty string, returns true if there are any tags of this
     type.
    */
    public bool contains_tag( string extra ) {
      if( extra == "" ) {
        return( _info.length > 0 );
      } else {
        for( int i=0; i<_info.length; i++ ) {
          if( _info.index( i ).extra == extra ) {
            return( true );
          }
        }
        return( false );
      }
    }

    /* Returns all of the extra values for this tag */
    public void get_extras_for_tag( ref HashMap<string,bool> extras ) {
      for( int i=0; i<_info.length; i++ ) {
        var extra = _info.index( i ).extra;
        if( !extras.has_key( extra ) ) {
          extras.@set( extra, true );
        }
      }
    }

    /* Returns the full tag ranges which overlap with the given range */
    public void get_full_tags_in_range( int tag, int start, int end, ref Array<UndoTagInfo> tags ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (start < info.end) && (end > info.start) ) {
          tags.append_val( new UndoTagInfo( tag, info.start, info.end, info.extra ) );
        }
      }
    }

    /* Returns all tags found within the given range */
    public void get_tags_in_range( int tag, int start, int end, ref Array<UndoTagInfo> tags ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (start < info.end) && (end > info.start) ) {
          var save_start = (info.start < start) ? start : info.start;
          var save_end   = (info.end   > end)   ? end   : info.end;
          tags.append_val( new UndoTagInfo( tag, (save_start - start), (save_end - start), info.extra ) );
        }
      }
    }

    /* Returns true if the given index contains this tag */
    public bool is_applied_at_index( int index ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (info.start <= index) && (index < info.end) ) {
          return( true );
        }
      }
      return( false );
    }

    /*
     Returns true if the given range overlaps with any tag; otherwise,
     returns false.
    */
    public bool is_applied_in_range( int start, int end ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (start < info.end) && (end > info.start) ) {
          return( true );
        }
      }
      return( false );
    }

    /* Inserts all of the attributes for this tag */
    public void get_attributes( TagAttr tag_attr, ref AttrList attrs ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        tag_attr.add_attrs( ref attrs, info.start, info.end, info.extra );
      }
    }

    /* Returns the extra data associated with the given cursor position */
    public string? get_extra( int index ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (info.start <= index) && (index < info.end) ) {
          return( info.extra );
        }
      }
      return( null );
    }

    /* Returns the first extra value found within the given range */
    public string? get_first_extra_in_range( int start, int end ) {
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        if( (start < info.end) && (end > info.start) ) {
          return( info.extra );
        }
      }
      return( null );
    }

    /* Returns the list of ranges this tag is associated with */
    public Xml.Node* save( string tag ) {
      Xml.Node* n = new Xml.Node( null, tag );
      for( int i=0; i<_info.length; i++ ) {
        var info = _info.index( i );
        n->add_child( info.save() );
      }
      return( n );
    }

    /* Loads the data from XML */
    public void load( Xml.Node* n ) {
      for( Xml.Node* it = n->children; it != null; it = it->next ) {
        if( (it->type == Xml.ElementType.ELEMENT_NODE) && (it->name == "range") ) {
          _info.append_val( new FormattedRange.from_xml( it ) );
        }
      }
    }

  }

  private class TagAttr {
    public Array<Pango.Attribute> attrs;
    public TagAttr() {
      attrs = new Array<Pango.Attribute>();
    }
    public TagAttr.copy_from( TagAttr ta ) {
      attrs = new Array<Pango.Attribute>();
      for( int i=0; i<ta.attrs.length; i++ ) {
        attrs.append_val( ta.attrs.index( i ).copy() );
      }
    }
    public virtual void add_attrs( ref AttrList list, int start, int end, string? extra ) {
      for( int i=0; i<attrs.length; i++ ) {
        var attr = attrs.index( i ).copy();
        attr.start_index = start;
        attr.end_index   = end;
        list.change( (owned)attr );
      }
    }
    public virtual TextTag text_tag( string? extra ) {
      return( new TextTag() );
    }
    protected RGBA get_color( string value ) {
      RGBA c = {(float)1.0, (float)1.0, (float)1.0, (float)1.0};
      c.parse( value );
      return( c );
    }
  }

  private class BoldInfo : TagAttr {
    public BoldInfo() {
      attrs.append_val( attr_weight_new( Weight.BOLD ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "bold" );
      ttag.weight     = Weight.BOLD;
      ttag.weight_set = true;
      return( ttag );
    }
  }

  private class ItalicsInfo : TagAttr {
    public ItalicsInfo() {
      attrs.append_val( attr_style_new( Pango.Style.ITALIC ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "italics" );
      ttag.style     = Pango.Style.ITALIC;
      ttag.style_set = true;
      return( ttag );
    }
  }

  private class UnderlineInfo : TagAttr {
    public UnderlineInfo() {
      attrs.append_val( attr_underline_new( Underline.SINGLE ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "underline" );
      ttag.underline     = Underline.SINGLE;
      ttag.underline_set = true;
      return( ttag );
    }
  }

  private class StrikeThruInfo : TagAttr {
    public StrikeThruInfo() {
      attrs.append_val( attr_strikethrough_new( true ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "strikethru" );
      ttag.strikethrough     = true;
      ttag.strikethrough_set = true;
      return( ttag );
    }
  }

  private class CodeInfo : TagAttr {
    public CodeInfo() {
      attrs.append_val( attr_family_new( "Monospace" ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "code" );
      ttag.family     = "Monospace";
      ttag.family_set = true;
      return( ttag );
    }
  }

  private class SubInfo : TagAttr {
    public SubInfo() {
      attrs.append_val( attr_rise_new( 0 - (4 * Pango.SCALE) ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "subscript" );
      ttag.rise     = 0 - (4 * Pango.SCALE);
      ttag.rise_set = true;
      return( ttag );
    }
  }

  private class SuperInfo : TagAttr {
    public SuperInfo() {
      attrs.append_val( attr_rise_new( 4 * Pango.SCALE ) );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "superscript" );
      ttag.rise     = (4 * Pango.SCALE);
      ttag.rise_set = true;
      return( ttag );
    }
  }

  private class HeaderInfo : TagAttr {
    public HeaderInfo() {}
    private double get_scale_factor( string? extra ) {
      switch( extra ) {
        case "1" :  return( 2.1 );
        case "2" :  return( 1.8 );
        case "3" :  return( 1.5 );
        case "4" :  return( 1.3 );
        case "5" :  return( 1.2 );
        case "6" :  return( 1.1 );
        default  :  return( 1.1 );
      }
    }
    public override void add_attrs( ref AttrList list, int start, int end, string? extra ) {
      var scale = attr_scale_new( get_scale_factor( extra ) );
      var bold  = attr_weight_new( Weight.BOLD );
      scale.start_index = start;
      scale.end_index   = end;
      list.change( (owned)scale );
      bold.start_index = start;
      bold.end_index   = end;
      list.change( (owned)bold );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "header" + extra );
      ttag.scale     = get_scale_factor( extra );
      ttag.scale_set = true;
      return( ttag );
    }
  }

  private class ColorInfo : TagAttr {
    public ColorInfo() {}
    public override void add_attrs( ref AttrList list, int start, int end, string? extra ) {
      var color = get_color( extra );
      var attr  = attr_foreground_new( (uint16)(color.red * 65535), (uint16)(color.green * 65535), (uint16)(color.blue * 65535) );
      attr.start_index = start;
      attr.end_index   = end;
      list.change( (owned)attr );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "color" + extra );
      ttag.foreground_rgba = get_color( extra );
      ttag.foreground_set  = true;
      return( ttag );
    }
  }

  private class HighlightInfo : TagAttr {
    public HighlightInfo() {}
    public override void add_attrs( ref AttrList list, int start, int end, string? extra ) {
      var color = get_color( extra );
      var bg    = attr_background_new( (uint16)(color.red * 65535), (uint16)(color.green * 65535), (uint16)(color.blue * 65535) );
      var alpha = attr_background_alpha_new( (uint16)(65536 * 0.5) );
      bg.start_index = start;
      bg.end_index   = end;
      list.change( (owned)bg );
      alpha.start_index = start;
      alpha.end_index   = end;
      list.change( (owned)alpha );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "hilite" + extra );
      ttag.background_rgba = get_color( extra );
      ttag.background_set  = true;
      return( ttag );
    }
  }

  private class UrlInfo : TagAttr {
    public UrlInfo( RGBA color ) {
      set_color( color );
    }
    private void set_color( RGBA color ) {
      attrs.append_val( attr_foreground_new( (uint16)(color.red * 65535), (uint16)(color.green * 65535), (uint16)(color.blue * 65535) ) );
      attrs.append_val( attr_underline_new( Underline.SINGLE ) );
    }
    public void update_color( RGBA color ) {
      attrs.remove_range( 0, 2 );
      set_color( color );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "url" );
      ttag.foreground      = "#0000ff";
      ttag.underline       = Underline.SINGLE;
      ttag.foreground_set  = true;
      ttag.underline_set   = true;
      return( ttag );
    }
  }

  private class TaggingInfo : TagAttr {
    private RGBA _color;
    public TaggingInfo( RGBA color ) {
      set_color( color );
    }
    private void set_color( RGBA color ) {
      attrs.append_val( attr_foreground_new( (uint16)(color.red * 65535), (uint16)(color.green * 65535), (uint16)(color.blue * 65535) ) );
      _color = color.copy();
    }
    public void update_color( RGBA color ) {
      attrs.remove_range( 0, 1 );
      set_color( color );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "tag" );
      ttag.foreground     = Utils.color_to_string( _color );
      ttag.foreground_set = true;
      return( ttag );
    }
  }

  private class SyntaxInfo : TagAttr {
    private RGBA _color;
    public SyntaxInfo( RGBA color ) {
      set_color( color );
    }
    private void set_color( RGBA color ) {
      attrs.append_val( attr_foreground_new( (uint16)(color.red * 65535), (uint16)(color.green * 65535), (uint16)(color.blue * 65535) ) );
      _color = color.copy();
    }
    public void update_color( RGBA color ) {
      attrs.remove_range( 0, 1 );
      set_color( color );
    }
    public override TextTag text_tag( string? extra ) {
      var ttag = new TextTag( "syntax" );
      ttag.foreground     = Utils.color_to_string( _color );
      ttag.foreground_set = true;
      return( ttag );
    }
  }

  private class MatchInfo : TagAttr {
    public MatchInfo( RGBA f, RGBA b ) {
      set_color( f, b );
    }
    private void set_color( RGBA f, RGBA b ) {
      attrs.append_val( attr_foreground_new( (uint16)(f.red * 65535), (uint16)(f.green * 65535), (uint16)(f.blue * 65535) ) );
      attrs.append_val( attr_background_new( (uint16)(b.red * 65535), (uint16)(b.green * 65535), (uint16)(b.blue * 65535) ) );
    }
    public void update_color( RGBA f, RGBA b ) {
      attrs.remove_range( 0, 2 );
      set_color( f, b );
    }
  }

  private class SelectInfo : TagAttr {
    public SelectInfo() {
      set_color( Utils.color_from_string( "white" ), Utils.color_from_string( "light blue" ) );
    }
    private void set_color( RGBA f, RGBA b ) {
      attrs.append_val( attr_foreground_new( (uint16)(f.red * 65535), (uint16)(f.green * 65535), (uint16)(f.blue * 65535) ) );
      attrs.append_val( attr_background_new( (uint16)(b.red * 65535), (uint16)(b.green * 65535), (uint16)(b.blue * 65535) ) );
    }
    public void update_color( RGBA f, RGBA b ) {
      attrs.remove_range( 0, 2 );
      set_color( f, b );
    }
  }

  private static TagAttr[]  _attr_tags = null;
  private TagInfo[]         _formats   = new TagInfo[FormatTag.LENGTH];
  private string            _text      = "";

  public signal void changed();

  public string text {
    get {
      return( _text );
    }
  }

  /* Default copy constructor */
  public FormattedText() {
    initialize();
  }

  /* Copy contructor with a string */
  public FormattedText.with_text( string txt ) {
    initialize();
    _text = txt;
  }

  /* Copies the selected portion of the given FormattedText instance to this instance */
  public FormattedText.copy_range( FormattedText text, int start, int end ) {
    initialize();
    _text = text.text.slice( start, end );
    var tags = text.get_tags_in_range( start, end );
    for( int i=0; i<tags.length; i++ ) {
      var tag = tags.index( i );
      _formats[tag.tag].add_tag( (tag.start - start), (tag.end - start), tag.extra );
    }
  }

  /* Creates a copy of the given text and removes all of the syntax characters */
  public FormattedText.copy_clean( FormattedText other ) {
    initialize();
    _text = other._text;
    for( int i=0; i<FormatTag.LENGTH-3; i++ ) {
      _formats[i].copy( other._formats[i] );
    }
  }

  /* Initializes this instance */
  private void initialize() {
    if( _attr_tags == null ) {
      _attr_tags = new TagAttr[FormatTag.LENGTH];
      _attr_tags[FormatTag.BOLD]       = new BoldInfo();
      _attr_tags[FormatTag.ITALICS]    = new ItalicsInfo();
      _attr_tags[FormatTag.UNDERLINE]  = new UnderlineInfo();
      _attr_tags[FormatTag.STRIKETHRU] = new StrikeThruInfo();
      _attr_tags[FormatTag.CODE]       = new CodeInfo();
      _attr_tags[FormatTag.SUB]        = new SubInfo();
      _attr_tags[FormatTag.SUPER]      = new SuperInfo();
      _attr_tags[FormatTag.HEADER]     = new HeaderInfo();
      _attr_tags[FormatTag.COLOR]      = new ColorInfo();
      _attr_tags[FormatTag.HILITE]     = new HighlightInfo();
      _attr_tags[FormatTag.SELECT]     = new SelectInfo();
    }
    for( int i=0; i<FormatTag.LENGTH; i++ ) {
      _formats[i] = new TagInfo();
    }
  }

  /* Copies the specified FormattedText instance to this one */
  public void copy( FormattedText other ) {
    _text = other._text;
    for( int i=0; i<FormatTag.LENGTH; i++ ) {
      _formats[i].copy( other._formats[i] );
    }
    changed();
  }

  /* Initializes the text to the given value */
  public void set_text( string str ) {
    _text = str;
  }

  /* Inserts a string into the given text */
  public void insert_text( int index, string str ) {
    _text = _text.splice( index, index, str );
    foreach( TagInfo f in _formats) {
      f.adjust( index, str.length );
    }
    changed();
  }

  /* Inserts the formatted text at the given position */
  public void insert_formatted_text( int index, FormattedText text ) {
    insert_text( index, text.text );
    for( int i=0; i<FormatTag.LENGTH-2; i++ ) {
      _formats[i].add_tags_at_offset( text._formats[i], index );
    }
  }

  /* Replaces the given text range with the given string */
  public void replace_text( int index, int chars, string str ) {
    _text = _text.splice( index, (index + chars), str );
    foreach( TagInfo f in _formats ) {
      f.remove_tag( index, (index + chars) );
      f.adjust( index, ((0 - chars) + str.length) );
    }
    changed();
  }

  /* Removes characters from the current text, starting at the given index */
  public void remove_text( int index, int chars ) {
    _text = _text.splice( index, (index + chars) );
    foreach( TagInfo f in _formats ) {
      f.remove_tag( index, (index + chars) );
      f.adjust( index, (0 - chars) );
    }
    changed();
  }

  /* Adds the given tag */
  public void add_tag( FormatTag tag, int start, int end, string? extra=null ) {
    _formats[tag].add_tag( start, end, extra );
    changed();
  }

  /* Replaces the given tag with the given range */
  public void replace_tag( FormatTag tag, int start, int end, string? extra=null ) {
    _formats[tag].replace_tag( start, end, extra );
    changed();
  }

  /* Removes the given tag */
  public void remove_tag( FormatTag tag, int start, int end ) {
    _formats[tag].remove_tag( start, end );
    changed();
  }

  /* Removes all ranges for the given tag */
  public void remove_tag_all( FormatTag tag ) {
    _formats[tag].remove_tag_all();
    changed();
  }

  /* Removes all formatting from the text */
  public void remove_all_tags( int start, int end ) {
    for( int i=0; i<FormatTag.LENGTH-3; i++ ) {
      _formats[i].remove_tag( start, end );
    }
    changed();
  }

  /* Returns true if the given tag is applied at the given index */
  public bool is_tag_applied_at_index( FormatTag tag, int index ) {
    return( _formats[tag].is_applied_at_index( index ) );
  }

  /* Returns true if the given tag is applied within the given range */
  public bool is_tag_applied_in_range( FormatTag tag, int start, int end ) {
    return( _formats[tag].is_applied_in_range( start, end ) );
  }

  /* Returns true if at least one tag is applied to the text */
  public bool tags_exist() {
    foreach( TagInfo f in _formats ) {
      if( !f.is_empty() ) {
        return( true );
      }
    }
    return( false );
  }

  /*
   Returns true if the given tag and extra information is found within this
   text.
  */
  public bool contains_tag( FormatTag tag, string extra = "" ) {
    return( _formats[tag].contains_tag( extra ) );
  }

  /* Retrieves the extra values for all items marked with tag */
  public HashMap<string,bool> get_extras_for_tag( FormatTag tag ) {
    var extras = new HashMap<string,bool>();
    _formats[tag].get_extras_for_tag( ref extras );
    return( extras );
  }

  /* Returns the tag information of the given tag in the specified range */
  public Array<UndoTagInfo> get_full_tags_in_range( FormatTag tag, int start, int end ) {
    var tags = new Array<UndoTagInfo>();
    for( int i=0; i<FormatTag.LENGTH-4; i++ ) {
      _formats[i].get_full_tags_in_range( i, start, end, ref tags );
    }
    return( tags );
  }

  /* Returns an array containing all tags that are within the specified range */
  public Array<UndoTagInfo> get_tags_in_range( int start, int end ) {
    var tags = new Array<UndoTagInfo>();
    for( int i=0; i<FormatTag.LENGTH-4; i++ ) {
      _formats[i].get_tags_in_range( i, start, end, ref tags );
    }
    return( tags );
  }

  /* Reapplies tags that were previously removed */
  public void apply_tags( Array<UndoTagInfo> tags, int start = 0 ) {
    for( int i=((int)tags.length - 1); i>=0; i-- ) {
      var info = tags.index( i );
      _formats[info.tag].add_tag( (info.start + start), (info.end + start), info.extra );
    }
    changed();
  }

  /*
   Returns the Pango attribute list to apply to the Pango layout.  This
   method should only be called if tags_exist returns true.
  */
  public AttrList get_attributes() {
    var attrs = new AttrList();
    for( int i=0; i<FormatTag.LENGTH; i++ ) {
      _formats[i].get_attributes( _attr_tags[i], ref attrs );
    }
    return( attrs );
  }

  /* Populate the given text buffer with the text and formatting tags */
  public void to_buffer( TextBuffer buf, int start, int end ) {
    buf.text = text;
    var tags = get_tags_in_range( start, end );
    TextIter ti_start, ti_end;
    for( int i=0; i<tags.length; i++ ) {
      var tag  = tags.index( i );
      var ttag = _attr_tags[tag.tag].text_tag( tag.extra );
      if( buf.tag_table.lookup( ttag.name ) == null ) {
        buf.tag_table.add( ttag );
      }
      buf.get_iter_at_offset( out ti_start, tag.start );
      buf.get_iter_at_offset( out ti_end,   tag.end );
      buf.apply_tag_by_name( ttag.name, ti_start, ti_end );
    }
  }

  /*
   Returns the extra data stored at the given index location, if one exists.
   If nothing is found, returns null.
  */
  public string? get_extra( FormatTag tag, int index ) {
    return( _formats[tag].get_extra( index ) );
  }

  /*
   Returns the first extra data stored in the given range, if any exist.  If nothing
   is found, returns null.
  */
  public string? get_first_extra_in_range( FormatTag tag, int start, int end ) {
    return( _formats[tag].get_first_extra_in_range( start, end ) );
  }

  /* Saves the text as the given XML node */
  public Xml.Node* save() {
    Xml.Node* n = new Xml.Node( null, "text" );
    n->new_prop( "data", text );
    for( int i=0; i<(FormatTag.LENGTH-4); i++ ) {
      if( !_formats[i].is_empty() ) {
        var tag = (FormatTag)i;
        n->add_child( _formats[i].save( tag.to_string() ) );
      }
    }
    return( n );
  }

  /* Loads the given XML information */
  public void load( Xml.Node* n ) {
    string? t = n->get_prop( "data" );
    if( t != null ) {
      _text = t;
    }
    for( Xml.Node* it = n->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        var tag = FormatTag.from_string( it->name );
        if( (tag != FormatTag.LENGTH) ) {
          _formats[tag].load( it );
        }
      }
    }
    changed();
  }

}

