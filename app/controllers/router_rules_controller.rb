class RouterRulesController < ApplicationController
  layout 'application'
  before_filter :require_admin

  # GET /router_rules
  # GET /router_rules.xml
  def index
    @router_rules = RouterRule.rules

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @router_rules }
    end
  end

  # GET /router_rules/1
  # GET /router_rules/1.xml
  def show
    @router_rule = RouterRule.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @router_rule }
    end
  end

  # GET /router_rules/new
  # GET /router_rules/new.xml
  def new
    @router_rule = RouterRule.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @router_rule }
    end
  end

  # GET /router_rules/1/edit
  def edit
    @router_rule = RouterRule.find(params[:id])
  end

  # POST /router_rules
  # POST /router_rules.xml
  def create
    @router_rule = RouterRule.new(params[:router_rule])

    respond_to do |format|
      if @router_rule.save
        format.html { redirect_to(@router_rule, :notice => 'RouterRule was successfully created.') }
        format.xml  { render :xml => @router_rule, :status => :created, :location => @router_rule }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @router_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /router_rules/1
  # PUT /router_rules/1.xml
  def update
    @router_rule = RouterRule.find(params[:id])

    respond_to do |format|
      if @router_rule.update_attributes(params[:router_rule])
        format.html { redirect_to(@router_rule, :notice => 'RouterRule was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @router_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /router_rules/1
  # DELETE /router_rules/1.xml
  def destroy
    @router_rule = RouterRule.find(params[:id])
    @router_rule.destroy

    respond_to do |format|
      format.html { redirect_to(router_rules_url) }
      format.xml  { head :ok }
    end
  end

  def ajax_test
    @rule = RouterRule.find_matching_rule(params[:phone])
    render :layout=>false
  end

end
