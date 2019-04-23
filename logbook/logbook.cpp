#include "logbook.h"

#include <QDateTime>
#include "Configuration.hpp"
#include "AD1CCty.hpp"

#include "moc_logbook.cpp"

LogBook::LogBook (Configuration const * configuration)
  : config_ {configuration}
{
  connect (&worked_before_, &WorkedBefore::finished_loading, this, &LogBook::finished_loading);
}

void LogBook::match (QString const& call, QString const& mode, QString const& grid,
                     AD1CCty::Record const& looked_up,
                     bool& callB4,
                     bool& countryB4,
                     bool& gridB4,
                     bool& continentB4,
                     bool& CQZoneB4,
                     bool& ITUZoneB4,
                     QString const& band) const
{
  if (call.length() > 0)
    {
      auto const& mode_to_check = (config_ && !config_->highlight_by_mode ()) ? QString {} : mode;
      callB4 = worked_before_.call_worked (call, mode_to_check, band);
      gridB4 = worked_before_.grid_worked(grid, mode_to_check, band);
      auto const& countryName = looked_up.entity_name;
      if (countryName.size ())
        {
          countryB4 = worked_before_.country_worked (countryName, mode_to_check, band);
          continentB4 = worked_before_.continent_worked (looked_up.continent, mode_to_check, band);
          CQZoneB4 = worked_before_.CQ_zone_worked (looked_up.CQ_zone, mode_to_check, band);
          ITUZoneB4 = worked_before_.ITU_zone_worked (looked_up.ITU_zone, mode_to_check, band);
        }
      else
        {
          countryB4 = true;  // we don't want to flag unknown entities
          continentB4 = true;
          CQZoneB4 = true;
          ITUZoneB4 = true;
        }
    }
}

bool LogBook::add (QString const& call
                   , QString const& grid
                   , QString const& band
                   , QString const& mode
                   , QByteArray const& ADIF_record)
{
  return worked_before_.add (call, grid, band, mode, ADIF_record);
}

void LogBook::rescan ()
{
  worked_before_.reload ();
}

QByteArray LogBook::QSOToADIF (QString const& hisCall, QString const& hisGrid, QString const& mode,
                               QString const& rptSent, QString const& rptRcvd, QDateTime const& dateTimeOn,
                               QDateTime const& dateTimeOff, QString const& band, QString const& comments,
                               QString const& name, QString const& strDialFreq, QString const& myCall,
                               QString const& myGrid, QString const& txPower, QString const& operator_call,
                               QString const& xSent, QString const& xRcvd)
{
  QString t;
  t = "<call:" + QString::number(hisCall.length()) + ">" + hisCall;
  t += " <gridsquare:" + QString::number(hisGrid.length()) + ">" + hisGrid;
  t += " <mode:" + QString::number(mode.length()) + ">" + mode;
  t += " <rst_sent:" + QString::number(rptSent.length()) + ">" + rptSent;
  t += " <rst_rcvd:" + QString::number(rptRcvd.length()) + ">" + rptRcvd;
  t += " <qso_date:8>" + dateTimeOn.date().toString("yyyyMMdd");
  t += " <time_on:6>" + dateTimeOn.time().toString("hhmmss");
  t += " <qso_date_off:8>" + dateTimeOff.date().toString("yyyyMMdd");
  t += " <time_off:6>" + dateTimeOff.time().toString("hhmmss");
  t += " <band:" + QString::number(band.length()) + ">" + band;
  t += " <freq:" + QString::number(strDialFreq.length()) + ">" + strDialFreq;
  t += " <station_callsign:" + QString::number(myCall.length()) + ">" + myCall;
  t += " <my_gridsquare:" + QString::number(myGrid.length()) + ">" + myGrid;
  if(txPower!="") t += " <tx_pwr:" + QString::number(txPower.length()) + ">" + txPower;
  if(comments!="") t += " <comment:" + QString::number(comments.length()) + ">" + comments;
  if(name!="") t += " <name:" + QString::number(name.length()) + ">" + name;
  if(operator_call!="") t+=" <operator:" + QString::number(operator_call.length()) + ">" + operator_call;
  if (xSent.size ())
    {
      auto words = xSent.split (' ', QString::SkipEmptyParts);
      if (words.size () > 1)
        {
          bool ok;
          auto sn = words.back ().toUInt (&ok);
          if (ok && sn)
            {
              // assume last word is a serial if there are at least
              // two words and if it is positive numeric
              t += " <STX:" + QString::number (words.back ().size ()) + '>' + words.back ();
            }
        }
    }
  if (xRcvd.size ()) {
    QString t1="";
    if(xRcvd.split(" ").size()==2) t1=xRcvd.split(" ").at(1);
    if(t1.toInt()>0) {
      t += " <SRX:" + QString::number(t1.length()) + ">" + t1;
    } else {
      t += " <STATE:" + QString::number(t1.length()) + ">" + t1;
    }
  }
  return t.toLatin1();
}
