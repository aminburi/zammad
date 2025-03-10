# Copyright (C) 2012-2022 Zammad Foundation, https://zammad-foundation.org/

class TimeAccountingsController < ApplicationController
  prepend_before_action { authentication_check && authorize! }

  def by_activity

    year = params[:year] || Time.zone.now.year
    month = params[:month] || Time.zone.now.month

    start_periode = Time.zone.parse("#{year}-#{month}-01")
    end_periode = start_periode.end_of_month

    records = []
    Ticket::TimeAccounting.where('created_at >= ? AND created_at <= ?', start_periode, end_periode).pluck(:ticket_id, :ticket_article_id, :time_unit, :created_by_id, :created_at).each do |record|
      records.push record
    end

    if !params[:download]
      customers = {}
      organizations = {}
      agents = {}
      results = []
      records.each do |record|
        ticket = Ticket.lookup(id: record[0])
        next if !ticket

        if !customers[ticket.customer_id]
          customers[ticket.customer_id] = '-'
          if ticket.customer_id
            customer_user = User.lookup(id: ticket.customer_id)
            if customer_user
              customers[ticket.customer_id] = customer_user.fullname
            end
          end
        end
        if !organizations[ticket.organization_id]
          organizations[ticket.organization_id] = '-'
          if ticket.organization_id
            organization = Organization.lookup(id: ticket.organization_id)
            if organization
              organizations[ticket.organization_id] = organization.name
            end
          end
        end
        if !agents[record[3]]
          agent_user = User.lookup(id: record[3])
          if agent_user
            agents[record[3]] = agent_user.fullname
          end
        end
        result = {
          ticket:       ticket.attributes,
          time_unit:    record[2],
          customer:     customers[ticket.customer_id],
          organization: organizations[ticket.organization_id],
          agent:        agents[record[3]],
          created_at:   record[4],
        }
        results.push result
      end
      render json: results
      return
    end

    header = [
      {
        name:  __('Ticket#'),
        width: 20,
      },
      {
        name:  __('Title'),
        width: 20,
      },
      {
        name:  "#{__('Customer')} - #{__('Name')}",
        width: 20,
      },
      {
        name:  __('Organization'),
        width: 20,
      },
      {
        name:  "#{__('Agent')} - #{__('Name')}",
        width: 20,
      },
      {
        name:  "#{__('Agent')} - #{__('Login')}",
        width: 20,
      },
      {
        name:      __('Time Units'),
        width:     10,
        data_type: 'float'
      },
      {
        name:  __('Created at'),
        width: 20,
      },
    ]
    results = []
    records.each do |record|
      ticket = Ticket.lookup(id: record[0])
      next if !ticket

      customer_name = User.lookup(id: record[3]).fullname
      organization_name = ''
      if ticket.organization_id.present?
        organization_name = Organization.lookup(id: ticket.organization_id).name
      end
      agent = User.lookup(id: record[3])

      result_row = [ticket.number, ticket.title, customer_name, organization_name, agent.fullname, agent.login, record[2], record[4]]
      results.push result_row
    end

    excel = ExcelSheet.new(
      title:    "By Activity #{year}-#{month}",
      header:   header,
      records:  results,
      timezone: params[:timezone],
      locale:   current_user.locale,
    )
    send_data(
      excel.content,
      filename:    "by_activity-#{year}-#{month}.xls",
      type:        'application/vnd.ms-excel',
      disposition: 'attachment'
    )
  end

  def by_ticket

    year = params[:year] || Time.zone.now.year
    month = params[:month] || Time.zone.now.month

    start_periode = Time.zone.parse("#{year}-#{month}-01")
    end_periode = start_periode.end_of_month

    time_unit = {}
    Ticket::TimeAccounting.where('created_at >= ? AND created_at <= ?', start_periode, end_periode).pluck(:ticket_id, :time_unit, :created_by_id).each do |record|
      if !time_unit[record[0]]
        time_unit[record[0]] = {
          time_unit: 0,
          agent_id:  record[2],
        }
      end
      time_unit[record[0]][:time_unit] += record[1]
    end

    if !params[:download]
      customers = {}
      organizations = {}
      agents = {}
      results = []
      time_unit.each do |ticket_id, local_time_unit|
        ticket = Ticket.lookup(id: ticket_id)
        next if !ticket

        if !customers[ticket.customer_id]
          customers[ticket.customer_id] = '-'
          if ticket.customer_id
            customer_user = User.lookup(id: ticket.customer_id)
            if customer_user
              customers[ticket.customer_id] = customer_user.fullname
            end
          end
        end
        if !organizations[ticket.organization_id]
          organizations[ticket.organization_id] = '-'
          if ticket.organization_id
            organization = Organization.lookup(id: ticket.organization_id)
            if organization
              organizations[ticket.organization_id] = organization.name
            end
          end
        end
        if !agents[local_time_unit[:agent_id]]
          agent_user = User.lookup(id: local_time_unit[:agent_id])
          if agent_user
            agents[local_time_unit[:agent_id]] = agent_user.fullname
          end
        end
        result = {
          ticket:       ticket.attributes,
          time_unit:    local_time_unit[:time_unit],
          customer:     customers[ticket.customer_id],
          organization: organizations[ticket.organization_id],
          agent:        agents[local_time_unit[:agent_id]],
        }
        results.push result
      end
      render json: results
      return
    end

    ticket_ids = []
    additional_attributes = []
    additional_attributes_header = [{ display: __('Time Units'), name: 'time_unit_for_range', width: 10, data_type: 'float' }]
    time_unit.each do |ticket_id, local_time_unit|
      ticket_ids.push ticket_id
      additional_attribute = {
        time_unit_for_range: local_time_unit[:time_unit],
      }
      additional_attributes.push additional_attribute
    end

    excel = ExcelSheet::Ticket.new(
      title:                        "Tickets: #{year}-#{month}",
      ticket_ids:                   ticket_ids,
      additional_attributes:        additional_attributes,
      additional_attributes_header: additional_attributes_header,
      timezone:                     params[:timezone],
      locale:                       current_user.locale,
    )

    send_data(
      excel.content,
      filename:    "by_ticket-#{year}-#{month}.xls",
      type:        'application/vnd.ms-excel',
      disposition: 'attachment'
    )
  end

  def by_customer

    year = params[:year] || Time.zone.now.year
    month = params[:month] || Time.zone.now.month

    start_periode = Time.zone.parse("#{year}-#{month}-01")
    end_periode = start_periode.end_of_month

    time_unit = {}
    Ticket::TimeAccounting.where('created_at >= ? AND created_at <= ?', start_periode, end_periode).pluck(:ticket_id, :time_unit, :created_by_id).each do |record|
      if !time_unit[record[0]]
        time_unit[record[0]] = {
          time_unit: 0,
          agent_id:  record[2],
        }
      end
      time_unit[record[0]][:time_unit] += record[1]
    end

    customers = {}
    time_unit.each do |ticket_id, local_time_unit|
      ticket = Ticket.lookup(id: ticket_id)
      next if !ticket

      if !customers[ticket.customer_id]
        organization = nil
        if ticket.organization_id
          organization = Organization.lookup(id: ticket.organization_id).attributes
        end
        customers[ticket.customer_id] = {
          customer:     User.lookup(id: ticket.customer_id).attributes,
          organization: organization,
          time_unit:    local_time_unit[:time_unit],
        }
        next
      end
      customers[ticket.customer_id][:time_unit] += local_time_unit[:time_unit]
    end
    results = []
    customers.each_value do |content|
      results.push content
    end

    if params[:download]
      header = [
        {
          name:  __('Customer'),
          width: 30,
        },
        {
          name:  __('Organization'),
          width: 30,
        },
        {
          name:      __('Time Units'),
          width:     10,
          data_type: 'float'
        }
      ]
      records = []
      results.each do |row|
        customer_name = User.find(row[:customer]['id']).fullname
        organization_name = ''
        if row[:organization].present?
          organization_name = row[:organization]['name']
        end
        result_row = [customer_name, organization_name, row[:time_unit]]
        records.push result_row
      end

      excel = ExcelSheet.new(
        title:    "By Customer #{year}-#{month}",
        header:   header,
        records:  records,
        timezone: params[:timezone],
        locale:   current_user.locale,
      )
      send_data(
        excel.content,
        filename:    "by_customer-#{year}-#{month}.xls",
        type:        'application/vnd.ms-excel',
        disposition: 'attachment'
      )
      return
    end

    render json: results
  end

  def by_organization

    year = params[:year] || Time.zone.now.year
    month = params[:month] || Time.zone.now.month

    start_periode = Time.zone.parse("#{year}-#{month}-01")
    end_periode = start_periode.end_of_month

    time_unit = {}
    Ticket::TimeAccounting.where('created_at >= ? AND created_at <= ?', start_periode, end_periode).pluck(:ticket_id, :time_unit, :created_by_id).each do |record|
      if !time_unit[record[0]]
        time_unit[record[0]] = {
          time_unit: 0,
          agent_id:  record[2],
        }
      end
      time_unit[record[0]][:time_unit] += record[1]
    end

    organizations = {}
    time_unit.each do |ticket_id, local_time_unit|
      ticket = Ticket.lookup(id: ticket_id)
      next if !ticket
      next if !ticket.organization_id

      if !organizations[ticket.organization_id]
        organizations[ticket.organization_id] = {
          organization: Organization.lookup(id: ticket.organization_id).attributes,
          time_unit:    local_time_unit[:time_unit],
        }
        next
      end
      organizations[ticket.organization_id][:time_unit] += local_time_unit[:time_unit]
    end
    results = []
    organizations.each_value do |content|
      results.push content
    end

    if params[:download]
      header = [
        {
          name:  __('Organization'),
          width: 40,
        },
        {
          name:      __('Time Units'),
          width:     20,
          data_type: 'float',
        }
      ]
      records = []
      results.each do |row|
        organization_name = ''
        if row[:organization].present?
          organization_name = row[:organization]['name']
        end
        result_row = [organization_name, row[:time_unit]]
        records.push result_row
      end

      excel = ExcelSheet.new(
        title:    "By Organization #{year}-#{month}",
        header:   header,
        records:  records,
        timezone: params[:timezone],
        locale:   current_user.locale,
      )
      send_data(
        excel.content,
        filename:    "by_organization-#{year}-#{month}.xls",
        type:        'application/vnd.ms-excel',
        disposition: 'attachment'
      )
      return
    end

    render json: results
  end
end
