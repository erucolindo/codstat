class Kill < ActiveRecord::Base
  def self.as_csv
    CSV.generate(:row_sep => "\r\n") do |csv|
      csv << column_names
      all.each do |item|
        csv << item.attributes.values_at(*column_names)
      end
    end
  end
end
