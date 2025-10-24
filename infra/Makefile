CRON_JOB = 0 */6 * * * cd $(PWD) && . .venv/bin/activate && python ./saving_fee_updater.py >> $(PWD)/update_fees.log 2>&1

install-cron:
	@echo "Installing cron job..."
	@(crontab -l 2>/dev/null; echo "$(CRON_JOB)") | crontab -
	@echo "✅ Cron installed: runs every 6h"

remove-cron:
	@echo "Removing cron job..."
	@crontab -l | grep -v 'saving_fee_updater.py' | crontab -
	@echo "🗑️ Cron job removed"

list-cron:
	@crontab -
