// monitortiem.h
#include <QQuickItem>
#include <QLoggingCategory>
#include <QStringList>

class MonitorItem : public QQuickItem {
    Q_OBJECT
public:
    explicit MonitorItem(QQuickItem *parent = nullptr);
    ~MonitorItem();

    // The bridge between the static handler and the instance
    static MonitorItem* s_instance;
    static void qtMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg);

    Q_INVOKABLE QStringList getCategories() const;

signals:
    // Signal to be consumed in QML
    void newMessage(QString category, int type, QString message);

private:
    void handleMessage(QtMsgType type, const QMessageLogContext &context, const QString &msg);
};