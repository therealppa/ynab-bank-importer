class Dumper
  # Implements logic to fetch transactions via the Fints protocol
  # and implements methods that convert the response to meaningful data.
  class Fints < Dumper
    require 'ruby_fints'
    require 'digest/md5'

    def initialize(params = {})
      @ynab_id  = params.fetch('ynab_id')
      @username = params.fetch('username').to_s
      @password = params.fetch('password').to_s
      @iban     = params.fetch('iban')
      @endpoint = params.fetch('fints_endpoint')
      @blz      = params.fetch('fints_blz')
    end

    def fetch_transactions
      FinTS::Client.logger.level = Logger::WARN
      client = FinTS::PinTanClient.new(@blz, @username, @password, @endpoint)

      account = client.get_sepa_accounts.find { |a| a[:iban] == @iban }
      statement = client.get_statement(account, Date.today - 35, Date.today)

      statement.map { |t| to_ynab_transaction(t) }
    end

    private

    def account_id
      @ynab_id
    end

    def date(transaction)
      transaction.entry_date || transaction.date
    end

    def payee_name(transaction)
      if !transaction.name.empty?
        name = transaction.name
      else
        name = transaction.sub_fields["21"].try(:strip)
      end
      #puts "NAME: #{name}"
      name
    end

    def payee_iban(transaction)
      transaction.iban
    end

    def memo(transaction)
      if transaction.sepa["SVWZ"]
        data = transaction.sepa["SVWZ"] + ' (' + transaction.description + ')'
      else
        data = transaction.sub_fields.values.join(' ').try(:strip)
      end
      #puts "MEMO: #{data}"
      data
    end

    def amount(transaction)
      amount =
        if transaction.funds_code == 'D'
          "-#{transaction.amount}"
        else
          transaction.amount
        end

      (amount.to_f * 1000).to_i
    end

    def withdrawal?(transaction)
      memo = memo(transaction)
      return nil unless memo

      memo.include?('Atm') || memo.include?('Bargeld') || memo.include?('BARGELDAUSZAHLUNG')
    end

    def import_id(transaction)
      return Digest::MD5.hexdigest(transaction.sha)
    end

  end
end
