# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def set_page_title(page_title)
    @page_title = page_title
  end
  
  def page_title
    @page_title.blank? ? "Lifeline" : "Lifeline - #{@page_title}"
  end
  
  #-----------------------------------------------------------------------------
  # create a link with an additional ':back' parameter pointing to the current page
  #--
  def link_to_with_back(text, params, options=nil)
    params[:back] = request.env['REQUEST_URI']
    link_to(text, params, options)
  end

  def cancel_link
    @back.blank? ? "" : link_to("Cancel", @back) #uvt
  end

  def back_here
    request.env['REQUEST_URI']
  end

  def link_to_trash(options, item_name)
    link_to(image_tag("/images/trash.gif", :style=>"vertical-align: middle;padding-bottom:5px;", :title=>''), 
    options, {:title => "Delete #{item_name}...", :confirm => "Are you sure you want to delete this #{item_name}?", :method => :delete})
  end
  
  def display_reachability(member)
    if member.pageable? 
      h(member.name) 
    else
       "<span class='unreachable'>#{h(member.name)} (#{h(member.display_status)})</span>"
    end
  end
  
  def display_forwarding_chain(member)
    
    return display_reachability(member) unless member.forward_to
    
    chain = h('> ') + member.forwarding_chain.map {|u| display_reachability(u) }.join(" > ")
    "<span class='forwarding_chain'> #{chain} </span>"
    
  end

  def display_sms_status(status)
    case status
    when STATUS_FAILED
      'FAILED'
    when STATUS_PENDING
      'PENDING'
    when STATUS_DELIVERED
      'DELIVERED'
    when STATUS_PARTIAL
      'PARTIAL'
    when STATUS_UNKNOWN
      'UNKNOWN'
    else
      '?????'
    end
  end
  
  def h_status(s)
    h(s).gsub(/&lt;br\/&gt;/, '<br/>')
  end
  
    
  def display_date(date)
    return '-' if date.nil?
     "#{date.localtime.to_s(:long)} (#{time_ago_in_words(date)} ago)"
  end

    
end
